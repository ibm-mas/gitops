{{- /*
Shell function shared by the PostSync verification test Jobs to notify Slack once the tests are complete.
Include inside a Job's command after the junit XML has been written to /tmp/junitxml_test_output.xml:

  {{- include "ibm-mas-suite-app-config.slack-notify" . | nindent 14 }}
  slack_notify || true

The message is posted with SlackUtil.postWebhookMessage from mas-devops (MASCORE-21754), so the CLI image the Job runs
must contain a mas-devops release that has it.

Expects these env vars on the Job: TEST_PASSED (shell var), JOB_NAME, BACKOFF_LIMIT, DEVOPS_ENVIRONMENT, DEVOPS_BUILD_NUMBER,
DEVOPS_SUITE_NAME.
Optional: SLACK_TEST_NAME, the readable name of the test shown in the title, e.g. "Manage verify". Defaults to "Verification".
Optional: INSTANCE_DOMAIN, shown as the "Domain" field. The field is left out when it is not set.
Optional: DEPLOYED_BY, shown as the "Deployed by" field. The field is left out when it is not set.
Optional: SLACK_SUITE_NAMES, a comma separated list of the suite names saved to Mongo, in the same order as the
<testsuite> elements in the junit XML. Defaults to DEVOPS_SUITE_NAME.

The Slack incoming webhook URL is read from /etc/mas/devops-uri/slack_webhook_url (the "slack_webhook_url" key of the
Job's devopsuri Secret, set from the slack_webhook_url chart value). If it is empty the message is only printed.
*/}}
{{- define "ibm-mas-suite-app-config.slack-notify" -}}
slack_notify() {
  # A failed Job pod is retried until backoffLimit is reached, so only notify about a failure on the last attempt.
  if [ "$TEST_PASSED" = "false" ]; then
    FAILED_ATTEMPTS=$(oc get job "$JOB_NAME" -o jsonpath='{.status.failed}' 2>/dev/null || true)
    if [ "${FAILED_ATTEMPTS:-0}" -lt "$BACKOFF_LIMIT" ]; then
      echo "Tests failed but Job will be retried (failed attempts: ${FAILED_ATTEMPTS:-0}/$BACKOFF_LIMIT), skipping Slack notification"
      return 0
    fi
  fi

  TEST_PASSED="$TEST_PASSED" python3 - /tmp/junitxml_test_output.xml <<'PYEOF'
import os
import sys
import xml.etree.ElementTree as ET


def mrkdwn(text):
    # Slack mrkdwn treats these three characters as control characters
    return str(text).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


passed_run = os.environ.get("TEST_PASSED") == "true"
instance = os.environ.get("DEVOPS_ENVIRONMENT")
build = os.environ.get("DEVOPS_BUILD_NUMBER") or "n/a"
test_name = os.environ.get("SLACK_TEST_NAME") or "Verification"
title = "*%s tests %s for %s*" % (mrkdwn(test_name), "PASSED" if passed_run else "FAILED", mrkdwn(instance))
color = "green" if passed_run else "red"

try:
    root = ET.parse(sys.argv[1]).getroot()
    suites = [s for s in (root if root.tag == "testsuites" else [root]) if s.tag == "testsuite"]
    suite_names = [n for n in (os.environ.get("SLACK_SUITE_NAMES") or os.environ.get("DEVOPS_SUITE_NAME") or "").split(",") if n]

    passed_total = failed_total = 0
    suite_lines = []
    failure_lines = []
    for index, suite in enumerate(suites):
        tests = failed = skipped = 0
        for case in suite.iter("testcase"):
            tests += 1
            problem = case.find("failure")
            if problem is None:
                problem = case.find("error")
            if problem is not None:
                failed += 1
                reason = (problem.get("message") or "").strip().replace("\n", " ")[:200]
                failure_lines.append("\u2022 %s: %s" % (mrkdwn(case.get("name")), mrkdwn(reason)))
            elif case.find("skipped") is not None:
                skipped += 1
        passed = tests - failed - skipped
        passed_total += passed
        failed_total += failed
        # Use the suite name recorded in Mongo (not the junit "pytest" name)
        suite_name = suite_names[index] if index < len(suite_names) else suite.get("name")
        suite_lines.append("\u2022 %s: %d passed, %d failed" % (mrkdwn(suite_name), passed, failed))

    fields = {"Instance ID": mrkdwn(instance)}
    if os.environ.get("INSTANCE_DOMAIN"):
        fields["Domain"] = mrkdwn(os.environ["INSTANCE_DOMAIN"])
    if os.environ.get("DEPLOYED_BY"):
        fields["Deployed by"] = mrkdwn(os.environ["DEPLOYED_BY"])
    fields.update({
        "Build": mrkdwn(build),
        "Total passed": str(passed_total),
        "Total failed": str(failed_total),
    })
    details = "*Test suites:*\n" + "\n".join(suite_lines)
    if failure_lines:
        details += "\n\n*Failed tests:*\n" + "\n".join(failure_lines)
    details = details[:2900]
except Exception as error:
    print("[slack] Unable to read junit results: %s" % error)
    fields = {"Instance ID": mrkdwn(instance), "Build": mrkdwn(build)}
    details = "Unable to read junit results."

try:
    with open("/etc/mas/devops-uri/slack_webhook_url") as webhook_file:
        webhook_url = webhook_file.read().strip()
except OSError:
    webhook_url = ""

if not webhook_url:
    print("[slack] No webhook URL configured, would have posted (%s):\n%s\n%s\n%s" % (color, title, fields, details))
    sys.exit(0)

from mas.devops.slack import SlackUtil  # noqa: E402

if SlackUtil.postWebhookMessage(webhook_url, title, fields, details, color):
    print("[slack] Notification sent")
else:
    print("[slack] Notification failed")
    sys.exit(1)
PYEOF
}
{{- end }}
