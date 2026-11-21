class_name Ocr
extends RefCounted
## Reads the text on pictures with the text reader that is part of Windows
## (Windows.Media.Ocr), reached through a small PowerShell script. Nothing
## leaves the computer and nothing is installed. On other systems `available()`
## is false and pictures are simply not read.
##
## It works beside the game instead of stopping it:
##   var job = Ocr.start({"images/a.png": bytes}, folder)   # {} when it could not start
##   var r = Ocr.poll(job)                                  # null while it is still working
##   r = {"ok", "error", "pages": {"images/a.png": page}}   # page: see game/shot_reader.gd
## The pictures are written to `folder` for the reader and removed afterwards.

const TIMEOUT_MS = 45000
const KINDS = ["jpg", "jpeg", "png", "bmp", "gif", "tif", "tiff"]

## Writes its answer as JSON (UTF-8) to -Out: for every picture its size and the
## lines found, each word with its box in pixels.
const SCRIPT = """param(
    [string]$Out,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Paths
)
$ErrorActionPreference = "Stop"
$result = @{ ok = $false; error = ""; lang = ""; images = @() }
try {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    $null = [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
    $null = [Windows.Storage.Streams.IRandomAccessStream, Windows.Storage.Streams, ContentType = WindowsRuntime]
    $null = [Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics, ContentType = WindowsRuntime]
    $null = [Windows.Graphics.Imaging.SoftwareBitmap, Windows.Graphics, ContentType = WindowsRuntime]
    $null = [Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType = WindowsRuntime]
    $asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
        $_.Name -eq "AsTask" -and $_.GetParameters().Count -eq 1 -and
        $_.GetParameters()[0].ParameterType.Name -eq "IAsyncOperation``1" })[0]
    function Await($op, $type) {
        $task = $asTask.MakeGenericMethod($type).Invoke($null, @($op))
        $task.Wait(-1) | Out-Null
        $task.Result
    }
    $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
    if ($null -eq $engine) {
        foreach ($l in [Windows.Media.Ocr.OcrEngine]::AvailableRecognizerLanguages) {
            $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage($l)
            if ($null -ne $engine) { break }
        }
    }
    if ($null -eq $engine) { throw "no-language" }
    $result.lang = $engine.RecognizerLanguage.LanguageTag
    foreach ($p in $Paths) {
        $img = @{ path = $p; ok = $false; error = ""; w = 0; h = 0; lines = @() }
        try {
            $file = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($p)) ([Windows.Storage.StorageFile])
            $stream = Await ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
            $decoder = Await ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
            $bmp = Await ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
            $ocr = Await ($engine.RecognizeAsync($bmp)) ([Windows.Media.Ocr.OcrResult])
            $img.w = [int]$bmp.PixelWidth
            $img.h = [int]$bmp.PixelHeight
            foreach ($line in $ocr.Lines) {
                $words = @()
                foreach ($w in $line.Words) {
                    $r = $w.BoundingRect
                    $words += , @{ t = $w.Text; x = [int]$r.X; y = [int]$r.Y; w = [int]$r.Width; h = [int]$r.Height }
                }
                $img.lines += , @{ t = $line.Text; words = $words }
            }
            $img.ok = $true
            $stream.Dispose()
        } catch {
            $img.error = $_.Exception.Message
        }
        $result.images += , $img
    }
    $result.ok = $true
} catch {
    $result.error = $_.Exception.Message
}
$json = $result | ConvertTo-Json -Depth 8 -Compress
[System.IO.File]::WriteAllText($Out, $json, (New-Object System.Text.UTF8Encoding($false)))
"""


static func available() -> bool:
	return OS.get_name() == "Windows"


static func _win(path: String) -> String:
	return path.replace("/", "\\")


static func _powershell() -> String:
	var root = OS.get_environment("SystemRoot")
	if root != "":
		var exe = root.replace("\\", "/").path_join("System32/WindowsPowerShell/v1.0/powershell.exe")
		if FileAccess.file_exists(exe):
			return _win(exe)
	return "powershell.exe"


## Start reading `files` ({name: picture bytes}); `folder` is where the pictures
## wait while they are read. Returns the job to poll, or {} when it could not start.
static func start(files: Dictionary, folder: String) -> Dictionary:
	if not available() or files.is_empty():
		return {}
	var dir = ProjectSettings.globalize_path(folder).replace("\\", "/").trim_suffix("/")
	if DirAccess.make_dir_recursive_absolute(dir) != OK and not DirAccess.dir_exists_absolute(dir):
		return {}
	var job = {"pid": -1, "dir": dir, "script": dir + "/read_text.ps1", "out": dir + "/answer.json",
		"names": {}, "paths": [], "started": Time.get_ticks_msec()}
	DirAccess.remove_absolute(job.out)
	var f = FileAccess.open(job.script, FileAccess.WRITE)
	if f == null:
		return {}
	f.store_string(SCRIPT)
	f.close()
	var args = ["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", _win(job.script), "-Out", _win(job.out)]
	var i = 0
	for name in files:
		var ext = str(name).get_extension().to_lower()
		if not KINDS.has(ext):
			ext = "png"
		var path = "%s/picture_%d.%s" % [dir, i, ext]
		i += 1
		var pf = FileAccess.open(path, FileAccess.WRITE)
		if pf == null:
			continue
		pf.store_buffer(files[name])
		pf.close()
		job.paths.append(path)
		job.names[_win(path)] = name
		args.append(_win(path))
	if job.paths.is_empty():
		_cleanup(job)
		return {}
	job.pid = OS.create_process(_powershell(), args)
	if int(job.pid) <= 0:
		_cleanup(job)
		return {}
	return job


## null while the reader is still working, else {"ok", "error", "pages": {name: page}}.
## A picture it could not open is simply missing from `pages`.
static func poll(job: Dictionary):
	if job.is_empty():
		return {"ok": false, "error": "not-started", "pages": {}}
	if OS.is_process_running(int(job.pid)):
		if Time.get_ticks_msec() - int(job.started) < TIMEOUT_MS:
			return null
		OS.kill(int(job.pid))
		_cleanup(job)
		return {"ok": false, "error": "timeout", "pages": {}}
	var text = FileAccess.get_file_as_string(job.out) if FileAccess.file_exists(job.out) else ""
	_cleanup(job)
	var data = JSON.parse_string(text) if text.strip_edges() != "" else null
	if not (data is Dictionary):
		return {"ok": false, "error": "no-answer", "pages": {}}
	if not bool(data.get("ok", false)):
		return {"ok": false, "error": str(data.get("error", "no-answer")), "pages": {}}
	var pages = {}
	for img in data.get("images", []):
		if img is Dictionary and bool(img.get("ok", false)) and job.names.has(str(img.get("path", ""))):
			pages[job.names[str(img.path)]] = ShotReader.page(img)
	return {"ok": true, "error": "", "pages": pages}


## Stop a job that is still working (the game is closing) and remove its files.
static func cancel(job: Dictionary) -> void:
	if job.is_empty():
		return
	if int(job.pid) > 0 and OS.is_process_running(int(job.pid)):
		OS.kill(int(job.pid))
	_cleanup(job)


static func _cleanup(job: Dictionary) -> void:
	for p in job.get("paths", []):
		DirAccess.remove_absolute(str(p))
	DirAccess.remove_absolute(str(job.get("script", "")))
	DirAccess.remove_absolute(str(job.get("out", "")))
	DirAccess.remove_absolute(str(job.get("dir", "")))
