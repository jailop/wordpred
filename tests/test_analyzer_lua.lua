-- test_analyzer.lua - Unit tests for frequency analyzer (Neovim/Lua version)
-- Run with: nvim --headless -u NONE -c "luafile tests/test_analyzer_lua.lua"

-- Test framework
local tests = {
  count = 0,
  passed = 0,
  failed = 0
}

local function assert_test(condition, message)
  tests.count = tests.count + 1
  if condition then
    tests.passed = tests.passed + 1
    print('PASS: ' .. message)
  else
    tests.failed = tests.failed + 1
    print('FAIL: ' .. message)
  end
end

local function assert_equal(expected, actual, message)
  local msg = message .. ' (expected: ' .. vim.inspect(expected) .. ', got: ' .. vim.inspect(actual) .. ')'
  assert_test(expected == actual, msg)
end

local function assert_greater(actual, threshold, message)
  local msg = message .. ' (expected > ' .. threshold .. ', got: ' .. actual .. ')'
  assert_test(actual > threshold, msg)
end

-- Create a test buffer with content
local function create_test_buffer(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  return bufnr
end

-- Load the analyzer module
package.path = package.path .. ';../lua/?.lua;../lua/?/init.lua'
local analyzer = require('wordpred.analyzer')

-- Test 1: Extract words with minimum length
local function test_word_extraction()
  print("\n=== Test: Word Extraction ===")
  
  local bufnr = create_test_buffer({
    'The quick brown fox jumps over the lazy dog.',
    'Hello world! Testing word prediction.',
    'ab cd xyz test'
  })
  
  analyzer.update_frequencies(bufnr)
  local stats = analyzer.get_stats(bufnr)
  
  assert_greater(stats.unique_words, 0, 'Should have extracted some words')
  
  local freq = analyzer.get_word_frequency('the', bufnr)
  assert_equal(2, freq, 'Word "the" should appear twice (case-insensitive)')
  
  local freq = analyzer.get_word_frequency('ab', bufnr)
  assert_equal(0, freq, 'Word "ab" should not be counted (too short)')
  
  vim.api.nvim_buf_delete(bufnr, { force = true })
end

-- Test 2: Case-insensitive counting
local function test_case_insensitive()
  print("\n=== Test: Case-Insensitive Counting ===")
  
  local bufnr = create_test_buffer({
    'Hello hello HELLO',
    'World WORLD world'
  })
  
  analyzer.update_frequencies(bufnr)
  
  local freq_hello = analyzer.get_word_frequency('hello', bufnr)
  assert_equal(3, freq_hello, 'Should count "Hello", "hello", "HELLO" as same word')
  
  local freq_world = analyzer.get_word_frequency('WORLD', bufnr)
  assert_equal(3, freq_world, 'Should count "World", "WORLD", "world" as same word')
  
  vim.api.nvim_buf_delete(bufnr, { force = true })
end

-- Test 3: Bigram frequency counting
local function test_bigram_counting()
  print("\n=== Test: Bigram Frequency ===")
  
  local bufnr = create_test_buffer({
    'hello world hello universe',
    'hello world again'
  })
  
  analyzer.update_frequencies(bufnr)
  
  local freq = analyzer.get_bigram_frequency('hello', 'world', bufnr)
  assert_equal(2, freq, 'Bigram "hello world" should appear twice')
  
  local freq = analyzer.get_bigram_frequency('hello', 'universe', bufnr)
  assert_equal(1, freq, 'Bigram "hello universe" should appear once')
  
  local freq = analyzer.get_bigram_frequency('world', 'test', bufnr)
  assert_equal(0, freq, 'Bigram "world test" should not exist')
  
  vim.api.nvim_buf_delete(bufnr, { force = true })
end

-- Test 4: Prefix matching
local function test_prefix_matching()
  print("\n=== Test: Prefix Matching ===")
  
  local bufnr = create_test_buffer({
    'testing tested test tester',
    'hello world wonderful'
  })
  
  analyzer.update_frequencies(bufnr)
  
  local matches = analyzer.get_words_with_prefix('test', bufnr)
  local count = 0
  for _ in pairs(matches) do count = count + 1 end
  
  assert_equal(3, count, 'Should find 3 words starting with "test"')
  assert_test(matches['testing'] ~= nil, 'Should find "testing"')
  assert_test(matches['tested'] ~= nil, 'Should find "tested"')
  assert_test(matches['tester'] ~= nil, 'Should find "tester"')
  assert_test(matches['test'] == nil, 'Should not include exact match "test"')
  
  local matches = analyzer.get_words_with_prefix('wo', bufnr)
  local count = 0
  for _ in pairs(matches) do count = count + 1 end
  assert_equal(2, count, 'Should find 2 words starting with "wo"')
  
  vim.api.nvim_buf_delete(bufnr, { force = true })
end

-- Test 5: Bigram prefix matching
local function test_bigram_prefix_matching()
  print("\n=== Test: Bigram Prefix Matching ===")
  
  local bufnr = create_test_buffer({
    'hello world hello wonderful hello wisdom',
    'goodbye world'
  })
  
  analyzer.update_frequencies(bufnr)
  
  local matches = analyzer.get_bigrams_with_prefix('hello', 'w', bufnr)
  local count = 0
  for _ in pairs(matches) do count = count + 1 end
  
  assert_equal(3, count, 'Should find 3 words after "hello" starting with "w"')
  assert_test(matches['world'] ~= nil, 'Should find "hello world"')
  assert_test(matches['wonderful'] ~= nil, 'Should find "hello wonderful"')
  assert_test(matches['wisdom'] ~= nil, 'Should find "hello wisdom"')
  
  local matches = analyzer.get_bigrams_with_prefix('goodbye', 'w', bufnr)
  local count = 0
  for _ in pairs(matches) do count = count + 1 end
  assert_equal(1, count, 'Should find 1 word after "goodbye" starting with "w"')
  
  vim.api.nvim_buf_delete(bufnr, { force = true })
end

-- Test 6: Update on buffer change
local function test_update_on_change()
  print("\n=== Test: Update on Change ===")
  
  local bufnr = create_test_buffer({'testing'})
  
  analyzer.update_frequencies(bufnr)
  local stats1 = analyzer.get_stats(bufnr)
  
  vim.api.nvim_buf_set_lines(bufnr, 1, 1, false, {'another line with more words'})
  analyzer.update_frequencies(bufnr)
  local stats2 = analyzer.get_stats(bufnr)
  
  assert_greater(stats2.unique_words, stats1.unique_words, 'Should have more words after adding content')
  assert_greater(stats2.last_tick, stats1.last_tick, 'Last tick should be updated')
  
  vim.api.nvim_buf_delete(bufnr, { force = true })
end

-- Test 7: Clear buffer data
local function test_clear_data()
  print("\n=== Test: Clear Data ===")
  
  local bufnr = create_test_buffer({'hello world testing'})
  
  analyzer.update_frequencies(bufnr)
  local stats1 = analyzer.get_stats(bufnr)
  assert_greater(stats1.unique_words, 0, 'Should have words before clear')
  
  analyzer.clear(bufnr)
  local stats2 = analyzer.get_stats(bufnr)
  assert_equal(0, stats2.unique_words, 'Should have no words after clear')
  assert_equal(0, stats2.unique_bigrams, 'Should have no bigrams after clear')
  
  vim.api.nvim_buf_delete(bufnr, { force = true })
end

-- Test 8: Empty buffer
local function test_empty_buffer()
  print("\n=== Test: Empty Buffer ===")
  
  local bufnr = create_test_buffer({''})
  
  analyzer.update_frequencies(bufnr)
  local stats = analyzer.get_stats(bufnr)
  
  assert_equal(0, stats.unique_words, 'Empty buffer should have no words')
  assert_equal(0, stats.unique_bigrams, 'Empty buffer should have no bigrams')
  
  vim.api.nvim_buf_delete(bufnr, { force = true })
end

-- Run all tests
local function run_all_tests()
  print("===================================")
  print("Running Word Prediction Analyzer Tests (Lua)")
  print("===================================")
  
  test_word_extraction()
  test_case_insensitive()
  test_bigram_counting()
  test_prefix_matching()
  test_bigram_prefix_matching()
  test_update_on_change()
  test_clear_data()
  test_empty_buffer()
  
  print("\n===================================")
  print("Test Results")
  print("===================================")
  print(string.format("Total tests:  %d", tests.count))
  print(string.format("Passed:       %d", tests.passed))
  print(string.format("Failed:       %d", tests.failed))
  print("===================================")
  
  if tests.failed == 0 then
    print("All tests passed! ✓")
    vim.cmd('quit')
  else
    print("Some tests failed! ✗")
    vim.cmd('cquit')
  end
end

-- Run tests
run_all_tests()
