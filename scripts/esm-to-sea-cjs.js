/**
 * Transforms the ESM bundle (dist/cli.js) into a CJS-compatible file for SEA.
 * - Converts static imports of external modules to require()
 * - Replaces import.meta.url with CJS equivalent
 * - Wraps the entire body in an async IIFE (to support top-level await)
 */

import { readFileSync, writeFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const inputPath = resolve(__dirname, '..', 'dist', 'cli.js');
const outputPath = resolve(__dirname, '..', 'dist', 'cli-sea.cjs');

let code = readFileSync(inputPath, 'utf8');

// Strip shebang line (not needed in SEA exe)
code = code.replace(/^#![^\n]*\n/, '');

// Replace import.meta.url with CJS equivalent
code = code.replace(/import\.meta\.url/g, '"file://" + __filename');

// Convert all import statements for external packages to require()
// Handles: import X from "pkg", import { a, b as c } from "pkg",
//          import * as X from "pkg", import X, { a } from "pkg",
//          import "pkg"
code = code.replace(
  /^import\s+(.+)\s+from\s+["']([^./][^"']*)["'];?$/gm,
  (match, clause, pkg) => {
    // Helper: convert "as" to ":" in destructured bindings
    const fixAs = (s) => s.replace(/\bas\b/g, ':');

    // import * as Foo from "pkg"
    const starMatch = clause.match(/^\*\s+as\s+(\w+)$/);
    if (starMatch) {
      return `var ${starMatch[1]} = require("${pkg}");`;
    }

    // import Default, { named } from "pkg"  or  import Default, * as NS from "pkg"
    const comboMatch = clause.match(/^(\w+)\s*,\s*(.+)$/);
    if (comboMatch) {
      const def = comboMatch[1];
      let rest = comboMatch[2].trim();
      const starRest = rest.match(/^\*\s+as\s+(\w+)$/);
      if (starRest) {
        return `var ${starRest[1]} = require("${pkg}"); var ${def} = ${starRest[1]}.default || ${starRest[1]};`;
      }
      // import Default, { a, b as c } from "pkg"
      rest = fixAs(rest);
      return `var __imp_${def} = require("${pkg}"); var ${def} = __imp_${def}.default || __imp_${def}; var ${rest} = __imp_${def};`;
    }

    // import { a, b as c } from "pkg"
    if (clause.startsWith('{')) {
      return `var ${fixAs(clause)} = require("${pkg}");`;
    }

    // import Default from "pkg"
    return `var ${clause} = require("${pkg}"); ${clause} = ${clause}.default || ${clause};`;
  },
);

// Convert: import "ext-package" (side-effect imports)
code = code.replace(/^import\s+["']([^./][^"']*)["'];?$/gm, (match, pkg) => {
  return `require("${pkg}");`;
});

// Remove/convert any top-level export statements (entry point, nothing exports)
code = code.replace(/^export\s*\{[^}]*\};?\s*$/gm, '');

// Wrap in async IIFE
code = `"use strict";
var { createRequire } = require("module");
var require = globalThis.require || createRequire(__filename);
(async () => {
${code}
})();
`;

writeFileSync(outputPath, code, 'utf8');
console.log('SEA CJS bundle written: dist/cli-sea.cjs');
