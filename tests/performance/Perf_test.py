"""
N01 Performance - small load test for my own Mayan EDMS scenarios (Roshan Khati).

Scenarios (one iteration per virtual user, repeated until the time is up):
  login_page      GET  /authentication/login/        (no login needed)
  cabinet_list    GET  /api/v4/cabinets/
  cabinet_create  POST /api/v4/cabinets/
  cabinet_detail  GET  /api/v4/cabinets/<id>/
  events_list     GET  /api/v4/events/               (skipped if the preflight check fails)
  cabinet_delete  DELETE /api/v4/cabinets/<id>/      (clean-up of the cabinet created above)

Only run this against your own local test instance. The password is read from the
environment variable MAYAN_PASSWORD (or asked for), and is never written to a file.

Usage (PowerShell, from the project folder):
    $env:MAYAN_PASSWORD = "your-password"
    python tests\\performance\\perf_test.py --levels 5,10,25 --duration 30
"""
import argparse, csv, getpass, os, random, statistics, string, sys, threading, time
import requests


def percentile(values, p):
    if not values:
        return 0.0
    v = sorted(values)
    k = max(0, min(len(v) - 1, int(round(p / 100.0 * len(v) + 0.5)) - 1))
    return v[k]


def timed(session, records, level, name, method, url, **kw):
    start = time.perf_counter()
    status, err = 0, ''
    resp = None
    try:
        resp = session.request(method, url, timeout=60, **kw)
        status = resp.status_code
    except Exception as exc:  # network error or timeout
        err = type(exc).__name__
    ms = (time.perf_counter() - start) * 1000.0
    ok = (status != 0 and status < 400)
    records.append((level, name, status, round(ms, 1), 0 if ok else 1, err))
    return resp, ok


def user_loop(base, auth, level, stop_at, think, records, include_events):
    s = requests.Session()
    s.auth = auth
    while time.time() < stop_at:
        timed(s, records, level, 'login_page', 'GET', base + '/authentication/login/')
        time.sleep(think)
        timed(s, records, level, 'cabinet_list', 'GET', base + '/api/v4/cabinets/')
        time.sleep(think)
        label = 'PERF_' + ''.join(random.choices(string.ascii_letters, k=8))
        resp, ok = timed(s, records, level, 'cabinet_create', 'POST', base + '/api/v4/cabinets/',
                         json={'label': label, 'parent': None})
        cab_id = None
        if ok:
            try:
                cab_id = resp.json()['id']
            except Exception:
                cab_id = None
        time.sleep(think)
        if cab_id:
            timed(s, records, level, 'cabinet_detail', 'GET', base + '/api/v4/cabinets/%s/' % cab_id)
            time.sleep(think)
        if include_events:
            timed(s, records, level, 'events_list', 'GET', base + '/api/v4/events/')
            time.sleep(think)
        if cab_id:
            timed(s, records, level, 'cabinet_delete', 'DELETE', base + '/api/v4/cabinets/%s/' % cab_id)
            time.sleep(think)


def preflight(base, auth):
    """Return True if the events endpoint answers 200; stop if the basics fail."""
    s = requests.Session()
    s.auth = auth
    checks = [('login page', '/authentication/login/'), ('cabinet list', '/api/v4/cabinets/')]
    for name, path in checks:
        r = s.get(base + path, timeout=30)
        print('  preflight %-14s HTTP %s' % (name, r.status_code))
        if r.status_code >= 400:
            sys.exit('Preflight failed for %s (HTTP %s). Check the URL, user name and password.' % (name, r.status_code))
    r = s.get(base + '/api/v4/events/', timeout=30)
    print('  preflight %-14s HTTP %s' % ('events list', r.status_code))
    return r.status_code == 200


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--base-url', default='http://localhost')
    ap.add_argument('--user', default='admin')
    ap.add_argument('--levels', default='5,10,25', help='comma-separated numbers of virtual users')
    ap.add_argument('--duration', type=int, default=30, help='seconds per level')
    ap.add_argument('--think', type=float, default=0.1, help='pause between requests (seconds)')
    ap.add_argument('--warmup', type=int, default=10, help='warm-up seconds with 2 users (not recorded)')
    ap.add_argument('--out', default='results_perf')
    a = ap.parse_args()

    password = os.environ.get('MAYAN_PASSWORD') or getpass.getpass('Mayan password: ')
    auth = (a.user, password)
    base = a.base_url.rstrip('/')
    levels = [int(x) for x in a.levels.split(',')]
    os.makedirs(a.out, exist_ok=True)

    print('Preflight checks against', base)
    include_events = preflight(base, auth)
    if not include_events:
        print('  (events endpoint not available: that step is skipped)')

    if a.warmup > 0:
        print('Warm-up for %s seconds (not recorded)...' % a.warmup)
        scratch = []
        ts = [threading.Thread(target=user_loop, args=(base, auth, 0, time.time() + a.warmup, a.think, scratch, include_events))
              for _ in range(2)]
        [t.start() for t in ts]; [t.join() for t in ts]

    all_records = []
    level_seconds = {}
    for n in levels:
        print('Level: %d virtual users for %d seconds...' % (n, a.duration))
        records = []
        t0 = time.time()
        stop_at = t0 + a.duration
        threads = [threading.Thread(target=user_loop, args=(base, auth, n, stop_at, a.think, records, include_events))
                   for _ in range(n)]
        [t.start() for t in threads]; [t.join() for t in threads]
        level_seconds[n] = time.time() - t0
        all_records.extend(records)
        print('  %d requests, %d errors' % (len(records), sum(r[4] for r in records)))

    with open(os.path.join(a.out, 'raw_requests.csv'), 'w', newline='') as f:
        w = csv.writer(f)
        w.writerow(['users', 'step', 'http_status', 'response_ms', 'error', 'exception'])
        w.writerows(all_records)

    rows = []
    for n in levels:
        recs = [r for r in all_records if r[0] == n]
        steps = []
        for r in recs:
            if r[1] not in steps:
                steps.append(r[1])
        for step in steps + ['ALL STEPS']:
            sel = [r for r in recs if step == 'ALL STEPS' or r[1] == step]
            ms = [r[3] for r in sel]
            errs = sum(r[4] for r in sel)
            rows.append([n, step, len(sel), errs,
                         round(100.0 * errs / len(sel), 1) if sel else 0,
                         round(len(sel) / level_seconds[n], 1),
                         round(statistics.mean(ms), 1) if ms else 0,
                         round(percentile(ms, 50), 1), round(percentile(ms, 95), 1),
                         round(max(ms), 1) if ms else 0])
    header = ['users', 'step', 'requests', 'errors', 'error_%', 'req_per_s', 'avg_ms', 'p50_ms', 'p95_ms', 'max_ms']
    with open(os.path.join(a.out, 'summary.csv'), 'w', newline='') as f:
        w = csv.writer(f); w.writerow(header); w.writerows(rows)
    with open(os.path.join(a.out, 'summary.md'), 'w') as f:
        f.write('| ' + ' | '.join(header) + ' |\n|' + '---|' * len(header) + '\n')
        for r in rows:
            f.write('| ' + ' | '.join(str(x) for x in r) + ' |\n')

    print('\nSummary (all steps combined per level):')
    print('%6s %9s %7s %9s %8s %8s %8s' % ('users', 'requests', 'errors', 'req/s', 'avg ms', 'p95 ms', 'max ms'))
    for r in rows:
        if r[1] == 'ALL STEPS':
            print('%6s %9s %7s %9s %8s %8s %8s' % (r[0], r[2], r[3], r[5], r[6], r[8], r[9]))
    print('\nPer-step table: %s' % os.path.join(a.out, 'summary.md'))
    print('Raw data:       %s' % os.path.join(a.out, 'raw_requests.csv'))


if __name__ == '__main__':
    main()