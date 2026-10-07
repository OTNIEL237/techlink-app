const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, '..', 'Rapport de stage niveau 3vvv.doc');
const buffer = fs.readFileSync(filePath);

console.log('File size:', buffer.length);
console.log('First 16 bytes hex:', buffer.slice(0, 16).toString('hex'));

// Check if it's a zip (PK.. -> docx)
if (buffer[0] === 0x50 && buffer[1] === 0x4B) {
  console.log('Type: ZIP / DOCX');
} else if (buffer[0] === 0xD0 && buffer[1] === 0xCF && buffer[2] === 0x11 && buffer[3] === 0xE0) {
  console.log('Type: OLE Compound Document (DOC)');
} else {
  console.log('Type: Other / Unknown');
}

// Search for ASCII / UTF-16LE text in the binary
// Extract all printable text sequences of length >= 6
let textParts = [];
let current = [];

// Try UTF-16LE extraction (common in Word docs)
let utf16Chars = [];
for (let i = 0; i < buffer.length - 1; i += 2) {
  const code = buffer.readUInt16LE(i);
  if ((code >= 32 && code <= 126) || (code >= 160 && code <= 255) || code === 10 || code === 13) {
    utf16Chars.push(String.fromCharCode(code));
  } else {
    if (utf16Chars.length >= 8) {
      textParts.push(utf16Chars.join(''));
    }
    utf16Chars = [];
  }
}
if (utf16Chars.length >= 8) {
  textParts.push(utf16Chars.join(''));
}

// Try ASCII extraction
let asciiChars = [];
for (let i = 0; i < buffer.length; i++) {
  const b = buffer[i];
  if ((b >= 32 && b <= 126) || (b >= 160 && b <= 255) || b === 10 || b === 13) {
    asciiChars.push(String.fromCharCode(b));
  } else {
    if (asciiChars.length >= 8) {
      textParts.push(asciiChars.join(''));
    }
    asciiChars = [];
  }
}
if (asciiChars.length >= 8) {
  textParts.push(asciiChars.join(''));
}

const allText = textParts.join('\n');
fs.writeFileSync(path.join(__dirname, 'extracted_report_text.txt'), allText, 'utf8');
console.log('Extracted lines of text:', textParts.length);

// Search for keywords like "bibliographie", "webographie", "auteur", "livre", "ouvrage", "référence"
const lines = allText.split('\n');
const matching = lines.filter(l => /biblio|webograph|référence|reference|ouvrage|auteur|isbn|edition|édit/i.test(l));
console.log('Found matching lines:', matching.length);
fs.writeFileSync(path.join(__dirname, 'matching_lines.txt'), matching.slice(0, 200).join('\n'), 'utf8');
console.log('Sample matches written.');
