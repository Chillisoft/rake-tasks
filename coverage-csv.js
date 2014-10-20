var path = require('path'),
        fs = require('fs'),
        istanbul = require('istanbul'),
        Report = istanbul.Report,
        Collector = istanbul.Collector,
        mkdirp = require('./node_modules/istanbul/node_modules/mkdirp'),
        utils = require('./node_modules/istanbul/lib/object-utils'),
        filesFor = require('./node_modules/istanbul/lib/util/file-matcher').filesFor;

function CsvSummaryReport(opts) {
    Report.call(this);
    opts = opts || {};
    this.dir = opts.dir || process.cwd();
    this.file = opts.file;
}

CsvSummaryReport.TYPE = 'csv-summary';

Report.register(CsvSummaryReport);

function headingsForKey(key) {
    return [key + '-coverage', key + '-covered', key + '-total'].join(',');
}

function metricsForKey(summary, key) {
    var metrics = summary[key];
    return [metrics.pct, metrics.covered, metrics.total].join(',');
}

Report.mix(CsvSummaryReport, {
    writeReport: function(collector) {
        var summaries = [],
                finalSummary,
                headings = [],
                values = [],
                text;
        collector.files().forEach(function(file) {
            summaries.push(utils.summarizeFileCoverage(collector.fileCoverageFor(file)));
        });
        finalSummary = utils.mergeSummaryObjects.apply(null, summaries);
        headings.push(headingsForKey('statements'));
        headings.push(headingsForKey('branches'));
        headings.push(headingsForKey('functions'));
        headings.push(headingsForKey('lines'));
        values.push(metricsForKey(finalSummary, 'statements'));
        values.push(metricsForKey(finalSummary, 'branches'));
        values.push(metricsForKey(finalSummary, 'functions'));
        values.push(metricsForKey(finalSummary, 'lines'));
        text = headings.join(',') + '\n' + values.join(',') + '\n';
        if (this.file) {
            mkdirp.sync(this.dir);
            fs.writeFileSync(path.join(this.dir, this.file), text, 'utf8');
        } else {
            console.log(text);
        }
    }
});

var buildreports_location = process.argv[2] || 'buildreports';

var reporter = Report.create('csv-summary', {root: buildreports_location,
    dir: buildreports_location, file: 'coverage.csv'});
var collector = new Collector();

filesFor({
    root: buildreports_location,
    includes: ['coverage.json']
}, function(err, files) {
    console.log('Using reporter [csv-summary]');
    if (!err && !files.length) {
        err = "ERROR: Could not find coverage.json. Ensure Karma has JSON coverageReporter configured";
    }
    if (err) {
        throw err;
    }
    files.forEach(function(file) {
        var coverageObject = JSON.parse(fs.readFileSync(file, 'utf8'));
        collector.add(coverageObject);
    });
    reporter.writeReport(collector);
    console.log('Done');
});
