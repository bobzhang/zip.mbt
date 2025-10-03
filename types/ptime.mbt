///|
/// POSIX time utilities for ZIP archives

///|
/// POSIX time (seconds since Unix epoch: 1970-01-01 00:00:00 UTC)
pub typealias Int as Ptime

///|
/// DOS epoch: 1980-01-01 00:00:00 UTC (in POSIX time)
/// This is the earliest representable time in ZIP archives
pub let dos_epoch : Ptime = 315532800

///|
let jd_posix_epoch : Int = 2440588 // Julian day of POSIX epoch

///|
/// Convert POSIX time to ((year, month, day), (hour, minute, second))
pub fn ptime_to_date_time(
  ptime_s : Ptime,
) -> ((Int, Int, Int), (Int, Int, Int)) {
  // Calculate Julian day
  let jd = ptime_s / 86400 + jd_posix_epoch
  let jd_rem = ptime_s % 86400

  // Time components
  let hh = jd_rem / 3600
  let hh_rem = jd_rem % 3600
  let mm = hh_rem / 60
  let ss = hh_rem % 60

  // Date from Julian day (algorithm from ptime library)
  let a = jd + 32044
  let b = (4 * a + 3) / 146097
  let c = a - 146097 * b / 4
  let d = (4 * c + 3) / 1461
  let e = c - 1461 * d / 4
  let m = (5 * e + 2) / 153
  let day = e - (153 * m + 2) / 5 + 1
  let month = m + 3 - 12 * (m / 10)
  let year = 100 * b + d - 4800 + m / 10
  ((year, month, day), (hh, mm, ss))
}

///|
/// Convert MS-DOS date/time to POSIX time
///
/// # Parameters
/// - `dos_date`: 16-bit DOS date value (UInt16)
///   - Bits 0-4: Day of month (1-31)
///   - Bits 5-8: Month (1-12)
///   - Bits 9-15: Year offset from 1980 (0-127, represents 1980-2107)
/// - `dos_time`: 16-bit DOS time value (UInt16)
///   - Bits 0-4: Seconds/2 (0-29, represents 0-58 seconds in 2-second intervals)
///   - Bits 5-10: Minutes (0-59)
///   - Bits 11-15: Hours (0-23)
///
/// # Returns
/// POSIX timestamp (seconds since Unix epoch: 1970-01-01 00:00:00 UTC)
///
/// # Notes
/// - Both parameters are native `UInt16` types as stored in ZIP file format
/// - Valid range: 1980-01-01 00:00:00 to 2107-12-31 23:59:58
/// - If `dos_date < 0x21` (before 1980-01-01), returns `dos_epoch` (1980-01-01)
/// - The ZIP format uses this encoding as defined in PKWARE's APPNOTE.TXT
pub fn ptime_of_dos_date_time(dos_date : UInt16, dos_time : UInt16) -> Ptime {
  if dos_date < 0x21 {
    // Before 1980-01-01
    dos_epoch
  } else {
    // Extract time components
    let hh = dos_time >> 11
    let mm = (dos_time >> 5) & 0x3F
    let ss = (dos_time & 0x1F) * 2

    // Extract date components and compute Julian day
    let year = ((dos_date >> 9) & 0x7F) + 1980
    let month = (dos_date >> 5) & 0xF
    let day = dos_date & 0x1F

    // Julian day calculation
    let a = (14 - month.to_int()) / 12
    let y = year.to_int() + 4800 - a
    let m = month.to_int() + 12 * a - 3
    let jd = day.to_int() +
      (153 * m + 2) / 5 +
      365 * y +
      y / 4 -
      y / 100 +
      y / 400 -
      32045
    let d = jd - jd_posix_epoch
    d * 86400 + hh.to_int() * 3600 + mm.to_int() * 60 + ss.to_int()
  }
}

///|
/// Convert POSIX time to MS-DOS date/time format
///
/// # Parameters
/// - `ptime_s`: POSIX timestamp (seconds since Unix epoch: 1970-01-01 00:00:00 UTC)
///
/// # Returns
/// A tuple `(dos_date, dos_time)` of UInt16 values:
/// - `dos_date`: 16-bit DOS date with bits:
///   - Bits 0-4: Day of month (1-31)
///   - Bits 5-8: Month (1-12)
///   - Bits 9-15: Year offset from 1980 (0-127, represents 1980-2107)
/// - `dos_time`: 16-bit DOS time with bits:
///   - Bits 0-4: Seconds/2 (0-29, represents 0-58 seconds in 2-second intervals)
///   - Bits 5-10: Minutes (0-59)
///   - Bits 11-15: Hours (0-23)
///
/// # Notes
/// - Times before 1980-01-01 are clamped to 1980-01-01 00:00:00
/// - Times after 2107-12-31 are clamped to 2107-12-31 23:59:59
/// - Returns native `UInt16` types as required by ZIP file format
/// - Seconds are stored in 2-second intervals (precision loss)
/// - The ZIP format uses this encoding as defined in PKWARE's APPNOTE.TXT
pub fn ptime_to_dos_date_time(ptime_s : Ptime) -> (UInt16, UInt16) {
  let date_time = ptime_to_date_time(ptime_s)
  let ((y, _, _), _) = date_time
  let ((year, month, day), (hh, mm, ss)) = if y < 1980 {
    ((1980, 1, 1), (0, 0, 0))
  } else if y > 2107 {
    ((2107, 12, 31), (23, 59, 59))
  } else {
    date_time
  }
  let dos_date = day.to_uint16() |
    (month.to_uint16() << 5) |
    ((year - 1980).to_uint16() << 9)
  let dos_time = (ss / 2).to_uint16() |
    (mm.to_uint16() << 5) |
    (hh.to_uint16() << 11)
  (dos_date, dos_time)
}

///|
/// Format POSIX time as RFC 3339 (without T separator)
pub fn ptime_format(ptime : Ptime) -> String {
  let ((year, month, day), (hh, mm, ss)) = ptime_to_date_time(ptime)
  // Format: YYYY-MM-DD HH:MM:SSZ
  fn pad2(n : Int) -> String {
    if n < 10 {
      "0" + n.to_string()
    } else {
      n.to_string()
    }
  }

  fn pad4(n : Int) -> String {
    if n < 10 {
      "000" + n.to_string()
    } else if n < 100 {
      "00" + n.to_string()
    } else if n < 1000 {
      "0" + n.to_string()
    } else {
      n.to_string()
    }
  }

  pad4(year) +
  "-" +
  pad2(month) +
  "-" +
  pad2(day) +
  " " +
  pad2(hh) +
  ":" +
  pad2(mm) +
  ":" +
  pad2(ss) +
  "Z"
}
