///|
test "fib" {
  let array = [1, 2, 3, 4, 5].map(x => fib(x))

  // `inspect` is used to check the output of the function
  // Just write `inspect(value)` and execute `moon test --update`
  // to update the expected output, and verify them afterwards
  @json.inspect(array, content="[1, 2, 3, 5, 8]")
}
