const convert = require('xml-js');
const fs = require('fs');
const {getAllFiles} = require('./utils');

console.log('Scanning TS files...');
const tsFiles = getAllFiles('../../ui/i18n', 'ts');

const options = {compact: true, spaces: 4};

tsFiles.forEach(file => {
    if (file.endsWith('base.ts')) {
        // We skip the base file
        return;
    }
    const fileContent = fs.readFileSync(file).toString();
    const json = convert.xml2js(fileContent, options);

    const doctype = json["_doctype"];
    let language = json[doctype]._attributes.language;
    const isEn = language === 'en_US'

    let translations;
    try {
        translations = require(`./status-react-translations/${language}.json`)
    } catch (e) {
        // No translation file for the exact match, let's use the file name instead
        const match = /qml_([a-zA-Z0-9_]+)\.ts/.exec(file)
        language = language || match[1];
        try {
            translations = require(`./status-react-translations/${match[1]}.json`)
        } catch (e) {
            console.error(`No translation file found for ${language}`);
            return;
        }
    }

    let messages = []
    if (json[doctype].context.length) {
      messages = json[doctype].context.flatMap(c => c.message)
    } else {
      messages = json[doctype].context.message;
    }

    console.log(`Modying ${language}...`)
    messages.forEach(message => {
        if (!message._attributes || !message._attributes.id) {
            return;
        }
        if (isEn) {
            // We just put the source string in the tranlsation
            message.translation = {
                "_text": message.source._text
            }
            return;
        }
        const messageId = message._attributes.id;
        if (!translations[messageId]) {
            // Skip this message, as we have no translation
            return;
        }

        message.translation = {
            "_text": translations[messageId]
        }
    });

    const xml = convert.js2xml(json, options);

    fs.writeFileSync(file, xml);
});

console.log('All done!')
