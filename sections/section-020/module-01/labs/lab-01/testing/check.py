#!/usr/bin/env python3
"""Read resource contracts and run bounded behavior checks in one lab context."""
import json
from pathlib import Path
import subprocess
import sys

DIRECTORY = Path(__file__).resolve().parent


def command(args, *, success=True):
    result = subprocess.run(args, capture_output=True, text=True, timeout=20)
    if success:
        assert result.returncode == 0, 'Required command failed: ' + args[0]
    return result


def kubectl(*args):
    return command(['kubectl', *args]).stdout.strip()


def get(kind, name, namespace='starfleet'):
    scope = ['-n', namespace] if namespace else []
    return json.loads(kubectl(*scope, 'get', kind, name, '-o', 'json'))


def contains(actual, expected):
    """Allow server-defaulted fields while preserving declared fields and lists."""
    if isinstance(expected, dict):
        return isinstance(actual, dict) and all(key in actual and contains(actual[key], value) for key, value in expected.items())
    if isinstance(expected, list):
        return isinstance(actual, list) and len(actual) == len(expected) and all(contains(left, right) for left, right in zip(actual, expected))
    return actual == expected


def resource_check(check):
    resource = get(check['kind'], check['name'], check.get('namespace', 'starfleet'))
    assert contains(resource, check['expected']), 'Required resource fields differ: ' + check['name']
    state = check.get('state')
    status = resource.get('status', {})
    if state == 'deployment':
        replicas = resource['spec'].get('replicas', 1)
        assert status.get('observedGeneration', 0) >= resource['metadata']['generation'], 'Current generation has not been observed'
        assert all(status.get(field, 0) == replicas for field in ('replicas', 'updatedReplicas', 'readyReplicas', 'availableReplicas')), 'Deployment rollout is incomplete'
    elif state == 'pod':
        assert status.get('phase') == 'Running' and any(condition['type'] == 'Ready' and condition['status'] == 'True' for condition in status.get('conditions', [])), 'Pod must be running and ready'
    elif state == 'job':
        assert status.get('succeeded', 0) == 1 and any(condition['type'] == 'Complete' and condition['status'] == 'True' for condition in status.get('conditions', [])), 'Job must complete successfully'
    elif state == 'pvc':
        assert status.get('phase') == 'Bound' and resource['spec'].get('volumeName'), 'Claim must bind to a volume'
    elif state == 'daemonset':
        desired = status.get('desiredNumberScheduled', 0)
        assert desired >= 2 and status.get('numberReady', 0) == desired and status.get('updatedNumberScheduled', 0) == desired, 'DaemonSet must cover both eligible nodes'
    return resource


def behavior_check(check):
    result = command(check['args'], success=not check.get('denied', False))
    if check.get('denied'):
        assert result.returncode == 1, 'Expected a bounded denied request, not a successful request or execution error'
        output = result.stdout + result.stderr
        assert any(marker in output.lower() for marker in check['failure_markers']), 'Request did not fail for the required reason'
    output = result.stdout.strip()
    if 'equals' in check:
        assert output == check['equals'], 'Command returned an unexpected value'
    for marker in check.get('contains', []):
        assert marker in output, 'Command did not return the expected application evidence'
    if 'json' in check:
        assert contains(json.loads(output), check['json']), 'Command returned an unexpected JSON contract'
    return result


def main():
    requirements = json.loads((DIRECTORY / 'requirements.json').read_text())
    assert kubectl('config', 'current-context') == requirements['context'], 'Refusing to operate on another Kubernetes context'
    for check in requirements['resources']:
        resource_check(check)
    for check in requirements.get('behavior', []):
        behavior_check(check)
    extra = DIRECTORY / 'live.py'
    if extra.exists():
        exec(compile(extra.read_text(), str(extra), 'exec'), globals())
    print('Required resource contract and behavior verified')


if __name__ == '__main__':
    try:
        main()
    except (AssertionError, KeyError, ValueError, subprocess.SubprocessError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
