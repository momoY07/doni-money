/**
 * In-memory limits (single instance). Keys are never logged. For several
 * instances, move these counters to a shared store (e.g. Redis).
 */
export class RateLimiter {
  constructor({ perMinute, perDay, dailyCeiling, now = () => Date.now() }) {
    this.perMinute = perMinute;
    this.perDay = perDay;
    this.dailyCeiling = dailyCeiling;
    this.now = now;
    this.minute = new Map();
    this.day = new Map();
    this.dayKey = null;
    this.total = 0;
  }

  /** Returns null when allowed, or 'rate_limited' / 'daily_limit'. */
  check(keys) {
    const now = this.now();
    const dayKey = Math.floor(now / 86_400_000);
    if (dayKey !== this.dayKey) {
      this.dayKey = dayKey;
      this.day.clear();
      this.total = 0;
    }
    const minuteKey = Math.floor(now / 60_000);
    for (const [k, v] of this.minute) if (v.window !== minuteKey) this.minute.delete(k);

    if (this.total >= this.dailyCeiling) return 'daily_limit';
    for (const key of keys) {
      const m = this.minute.get(key);
      if (m && m.count >= this.perMinute) return 'rate_limited';
      if ((this.day.get(key) ?? 0) >= this.perDay) return 'rate_limited';
    }
    for (const key of keys) {
      const m = this.minute.get(key) ?? { window: minuteKey, count: 0 };
      m.count += 1;
      this.minute.set(key, m);
      this.day.set(key, (this.day.get(key) ?? 0) + 1);
    }
    this.total += 1;
    return null;
  }
}
