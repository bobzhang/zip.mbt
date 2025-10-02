///|
/// Ptime tests
test "ptime_dos_epoch" {
  // 1980-01-01 00:00:00 UTC
  let ((year, month, day), (hh, mm, ss)) = ptime_to_date_time(dos_epoch)
  @json.inspect(((year, month, day), (hh, mm, ss)), content=[
    [1980, 1, 1],
    [0, 0, 0],
  ])
}

///|
test "ptime_to_date_time" {
  // Test with a known timestamp: 2023-06-15 12:30:45 UTC = 1686832245
  let ptime = 1686832245
  let ((year, month, day), (hh, mm, ss)) = ptime_to_date_time(ptime)
  @json.inspect(((year, month, day), (hh, mm, ss)), content=[
    [2023, 6, 15],
    [12, 30, 45],
  ])
}

///|
test "ptime_dos_roundtrip" {
  // Test DOS date/time roundtrip
  // 2000-06-15 14:30:00
  let dos_date = 15 | (6 << 5) | ((2000 - 1980) << 9) // day=15, month=6, year=2000
  let dos_time = 0 | (30 << 5) | (14 << 11) // sec=0, min=30, hour=14
  let ptime = ptime_of_dos_date_time(dos_date, dos_time)
  let (dos_date2, dos_time2) = ptime_to_dos_date_time(ptime)
  @json.inspect((dos_date == dos_date2, dos_time == dos_time2), content=[
    true, true,
  ])
}

///|
test "ptime_format" {
  // Format dos_epoch
  @json.inspect(ptime_format(dos_epoch), content="1980-01-01 00:00:00Z")
}
