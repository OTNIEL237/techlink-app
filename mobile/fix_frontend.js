const fs = require('fs');
const path = require('path');

function walk(dir) {
    let results = [];
    const list = fs.readdirSync(dir);
    list.forEach(function(file) {
        file = path.join(dir, file);
        const stat = fs.statSync(file);
        if (stat && stat.isDirectory()) { 
            results = results.concat(walk(file));
        } else { 
            if (file.endsWith('.dart')) results.push(file);
        }
    });
    return results;
}

const files = walk('c:/Users/Lenovo/techlink-app/mobile/lib');
let countCatches = 0;
let countButtons = 0;

for (const file of files) {
    let content = fs.readFileSync(file, 'utf8');
    let original = content;

    // Replace empty catches
    const catchRegex = /catch\s*\([^)]+\)\s*\{\s*\}/g;
    content = content.replace(catchRegex, () => {
        countCatches++;
        return "catch (e) { print('Erreur silencieuse interceptée: $e'); }";
    });

    // Replace empty buttons if flutter/material is imported
    if (content.includes('package:flutter/material.dart')) {
        const btnRegex = /onPressed:\s*\(\)\s*\{\s*\},/g;
        content = content.replace(btnRegex, () => {
            countButtons++;
            return "onPressed: () { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🚧 Fonctionnalité bientôt disponible'))); },";
        });
    }

    if (content !== original) {
        fs.writeFileSync(file, content, 'utf8');
    }
}

console.log(`Fixed ${countCatches} empty catch blocks.`);
console.log(`Fixed ${countButtons} empty onPressed buttons.`);
