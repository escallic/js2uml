var moment = require('moment');
moment.locale('en-US');

module.exports = configure = {
    "title": "TITLE",
    "header": "",
    "footer": "",
    "sourceFile": "",
    "output": "",
    "author": "",
    "borderColor": "#9932CC",
    "backgroundcolor": "#FFFFFF",
    "copyright": function() {
        return (configure.author ? " © " + configure.author + ' ': '') + moment().format('lll') + ", " + configure.footer;
    }
}
