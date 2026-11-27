import fs from 'node:fs';
import path from 'node:path';

/** Tiny JSON-file store with atomic writes. */
export class JsonFile<T> {
  constructor(private file: string) {
    fs.mkdirSync(path.dirname(file), { recursive: true });
  }

  exists(): boolean {
    return fs.existsSync(this.file);
  }

  read(): T | null {
    try {
      return JSON.parse(fs.readFileSync(this.file, 'utf8')) as T;
    } catch {
      return null;
    }
  }

  write(value: T): void {
    const tmp = `${this.file}.${process.pid}.tmp`;
    fs.writeFileSync(tmp, JSON.stringify(value, null, 2));
    fs.renameSync(tmp, this.file);
  }

  remove(): void {
    try {
      fs.unlinkSync(this.file);
    } catch {
      /* already gone */
    }
  }
}
