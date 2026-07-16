import * as fs from 'fs';
import * as path from 'path';

interface PackageManifest {
  name: string;
  version: string;
}

const manifestPath = path.join(__dirname, '..', 'package.json');
const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf-8')) as PackageManifest;

export const PACKAGE_NAME = manifest.name;
export const PACKAGE_VERSION = manifest.version;
