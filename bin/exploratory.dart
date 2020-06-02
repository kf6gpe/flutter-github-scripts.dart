import 'package:flutter_github_scripts/github_datatypes.dart';
import 'package:flutter_github_scripts/github_queries.dart';
import 'package:args/args.dart';
import 'dart:io';



class Options  {
  final _parser = ArgParser(allowTrailingOptions: false);
  ArgResults _results;
  bool get showClosed => _results['closed'];
  DateTime get from => DateTime.parse(_results.rest[0]);
  DateTime get to => DateTime.parse(_results.rest[1]);
  int get exitCode => _results == null ? -1 : _results['help'] ? 0 : null;

  Options(List<String> args) {
    _parser
      ..addFlag('help', defaultsTo: false, abbr: 'h', negatable: false, help: 'get usage')
      ..addFlag('closed', defaultsTo: false, abbr: 'c', negatable: false, help: 'show punted issues in date range');
    try {
      _results = _parser.parse(args);
      if (_results['help'])  _printUsage();
      if (_results['closed'] && _results.rest.length != 2 ) throw('need start and end dates!');
    } on ArgParserException catch (e) {
      print(e.message);
      _printUsage();
    }
  }

  void _printUsage() {
    print('Usage: pub exploratory prs.dart [-closed fromDate toDate]');
    // TODO
    print('TODO');
    print('  Dates are in ISO 8601 format');
    print(_parser.usage);
  }
}

void main(List<String> args) async {
  final opts = Options(args);
  if (opts.exitCode != null) exit(opts.exitCode);

  var repos = ['flutter', 'engine'];

  final token = Platform.environment['GITHUB_TOKEN'];
  final github = GitHub(token);

  var state = GitHubIssueState.open;
  DateRange when = null;
  var rangeType = GitHubDateQueryType.none;
  if (opts.showClosed) {
    state = GitHubIssueState.closed;
    when = DateRange(DateRangeType.range, start: opts.from, end: opts.to);
    rangeType = GitHubDateQueryType.closed;
  }

  var prs = List<dynamic>();
  for(var repo in repos) {
    prs.addAll(await github.search(owner: 'flutter', 
      name: repo, 
      type: GitHubIssueType.pullRequest,
      state: state,
      dateQuery: rangeType,
      dateRange: when
    ));
  }

  print(opts.showClosed ? 
    "# Closed PRs from " + opts.from.toIso8601String() + ' to ' + opts.to.toIso8601String() :
    "# Open PRs from" );

  if (false) {
    print('## All prs\n');
    for (var pr in prs) print(pr.summary(linebreakAfter: true));
    print('\n');
  }


  print("## Issues by milestone\n");
  print("There were ${issues.length} issues.\n");

  var clusters = Cluster.byMilestone(issues);
  print(clusters.toMarkdown(ClusterReportSort.byCount, true));

  print((opts.showClosed ? 
    "## Closed issues punted from " + opts.from.toIso8601String() + ' to ' + opts.to.toIso8601String() :
    "## Open issues punted") + ' by milestone');

  for(var item in issues) {
    // typecast so we have easy auto-completion in Visual Studio Code
    var issue = item as Issue;
    var countMilestoned = 0;
    var countDemilestoned = 0;
    if (issue.timeline == null || issue.timeline.length == 0) continue;
    for(var timelineItem in issue.timeline.timeline) {
      if (timelineItem.type == 'MilestonedEvent') {
        countMilestoned++;
      } else if (timelineItem.type == 'DemilestonedEvent') {
        countDemilestoned++;
      }
    }
    // Was it initially assigned a milestone on creation and didn't get an event?
    // I'm not sure if this can happen with GitHub, but we don't want to miss it.
    if(issue.milestone != null && countMilestoned == 0) countMilestoned++;
    if (countMilestoned >= 1 || countDemilestoned > 0) {
      print('Issue [#${issue.number}](${issue.url}) "${issue.title}" milestoned ${countMilestoned} times, ' + 
        'demilestoned ${countDemilestoned} times, now ' + 
        (issue.milestone == null ? 'not assigned a milestone' 
          : 'assigned to be ${issue.milestone}'));
      for(var timelineItem in issue.timeline.timeline) {
        if (timelineItem.type == 'MilestonedEvent') {
          print('...assigned the ${timelineItem.title} milestone');
        }
      }
      print('\n');
    }
  }
}
