# Word Prediction Vim Plugin

A Vim/Neovim plugin that provides intelligent word prediction based on the content of the current buffer, using statistical language modeling (unigram and bigram models).

## Project Status

**Current Phase: Week 7 (Documentation) - Completed ✓**

### Completed
- [x] Project structure setup
- [x] Frequency analyzer module (VimScript & Lua)
- [x] Unit tests for analyzer  
- [x] Prediction engine module (VimScript & Lua)
- [x] Unit tests for prediction engine
- [x] Display module (VimScript & Lua)
- [x] Main plugin integration
- [x] Interactive demo
- [x] Performance monitoring and profiling
- [x] Debouncing and throttling
- [x] Large buffer optimization
- [x] Advanced configuration options
- [x] Configuration guide (CONFIGURATION.md)
- [x] Vim help documentation (`:help wordpred`)
- [x] Usage examples (EXAMPLES.md)
- [x] Changelog (CHANGELOG.md)

### Next Steps (Week 8+)
- [ ] Advanced features (trigrams, persistence, cross-buffer learning)
- [ ] Integration with completion frameworks (nvim-cmp)
- [ ] Additional language support

## Documentation

- **Quick Start**: See below or run `:help wordpred-quickstart`
- **Full Documentation**: `:help wordpred` (comprehensive Vim help)
- **Configuration Guide**: [CONFIGURATION.md](CONFIGURATION.md) (detailed options)
- **Usage Examples**: [EXAMPLES.md](EXAMPLES.md) (12 practical examples)
- **Quick Reference**: [QUICKREF.md](QUICKREF.md) (one-page cheat sheet)
- **Implementation Details**: [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)
- **Project Plan**: [word-prediction-vim.md](../word-prediction-vim.md)

## Quick Start

### Installation

**Using vim-plug:**
```vim
Plug 'path/to/vim'
```

**Using Packer (Neovim):**
```lua
use 'path/to/vim'
```

**Manual:**
Copy the `vim` directory to your `~/.vim` or `~/.config/nvim` directory.

### Usage

The plugin works automatically once installed. As you type in insert mode:
1. Type a few characters of a word
2. A gray prediction appears inline (with source indicator ⚡ or ●)
3. Press `<Ctrl+J>` to accept the prediction
4. Press `<Ctrl+N>` to cycle to next candidate
5. Press `<Ctrl+P>` to cycle to previous candidate
6. Or continue typing to update/ignore

**New in v1.1**: Multiple candidates and visual source feedback!  
See [NEWFEATURES.md](NEWFEATURES.md) for details.

### Demo

Try the interactive demo:
```bash
vim -S demo.vim
```

### Configuration

**Basic VimScript (.vimrc):**
```vim
let g:wordpred_enabled = 1
let g:wordpred_min_prefix_length = 1
let g:wordpred_bigram_weight = 2
let g:wordpred_filetypes = []  " empty = all filetypes

" Keybindings (NEW in v1.1)
let g:wordpred_accept_key = '<C-j>'      " Accept prediction
let g:wordpred_cycle_next_key = '<C-n>'  " Next candidate
let g:wordpred_cycle_prev_key = '<C-p>'  " Previous candidate

" Visual feedback (NEW in v1.1)
let g:wordpred_show_source = 1           " Show ⚡ for bigram, ● for unigram
let g:wordpred_max_candidates = 5        " Max candidates to cycle through
```

**Basic Lua (init.lua):**
```lua
require('wordpred').setup({
  enabled = true,
  min_prefix_length = 1,
  bigram_weight = 2,
  filetypes = {},
  accept_key = '<C-j>',       -- NEW: changed from <Tab>
  cycle_next_key = '<C-n>',   -- NEW
  cycle_prev_key = '<C-p>',   -- NEW
  show_source = true,         -- NEW
  max_candidates = 5          -- NEW
})
```

**Performance Tuning:**
```vim
" Enable performance monitoring
let g:wordpred_perf_monitor = 1

" Debounce delay (ms) - reduces CPU usage
let g:wordpred_debounce_delay = 100

" Large buffer threshold (characters)
let g:wordpred_large_buffer_threshold = 100000

" Update every N changes
let g:wordpred_update_interval = 10
```

See [CONFIGURATION.md](CONFIGURATION.md) for detailed configuration guide.

### Commands

**Basic Commands:**
- `:WordPredEnable` - Enable word prediction
- `:WordPredDisable` - Disable word prediction
- `:WordPredToggle` - Toggle word prediction on/off
- `:WordPredEnableBuffer` - Enable for current buffer only
- `:WordPredDisableBuffer` - Disable for current buffer only
- `:WordPredStats` - Show frequency model statistics
- `:WordPredInfo` - Show current prediction information
- `:WordPredUpdate` - Manually update frequency model
- `:WordPredClear` - Clear frequency model for current buffer

**Performance Monitoring:**
- `:WordPredPerfEnable` - Enable performance monitoring
- `:WordPredPerfDisable` - Disable performance monitoring
- `:WordPredPerfStats` - Show performance statistics
- `:WordPredPerfReset` - Reset performance counters

## Project Structure

```
vim/
├── README.md                     # This file
├── CHANGELOG.md                  # ✓ Version history
├── CONFIGURATION.md              # ✓ Detailed configuration guide
├── EXAMPLES.md                   # ✓ 12 usage examples
├── QUICKREF.md                   # ✓ Quick reference card
├── IMPLEMENTATION_SUMMARY.md     # ✓ Technical details
├── demo.vim                      # ✓ Interactive demo
├── plugin/
│   └── wordpred.vim             # ✓ Main plugin integration
├── autoload/
│   └── wordpred/
│       ├── analyzer.vim         # ✓ Frequency analysis
│       ├── predict.vim          # ✓ Prediction engine
│       ├── display.vim          # ✓ Display management
│       └── performance.vim      # ✓ Performance monitoring
├── lua/                         # Neovim Lua implementation
│   └── wordpred/
│       ├── init.lua             # ✓ Main module
│       ├── analyzer.lua         # ✓ Frequency analysis
│       ├── predict.lua          # ✓ Prediction engine
│       ├── display.lua          # ✓ Display management
│       └── performance.lua      # ✓ Performance monitoring
├── doc/
│   ├── wordpred.txt             # ✓ Vim help documentation (650+ lines)
│   └── tags                     # ✓ Generated help tags
└── tests/
    ├── test_analyzer.vim        # ✓ Analyzer tests
    ├── test_analyzer_lua.lua    # ✓ Lua analyzer tests
    ├── test_predict.vim         # ✓ Predictor tests
    ├── example_analyzer.vim     # ✓ Analyzer example
    ├── benchmark.sh             # ✓ Performance benchmark
    └── run_tests.sh             # ✓ Test runner
```

## Architecture

### Frequency Analyzer Module

The analyzer module is responsible for:
- Parsing buffer text and extracting words (3+ alphabetic characters)
- Building unigram frequency maps: `{word -> count}`
- Building bigram frequency maps: `{(word1, word2) -> count}`
- Providing efficient prefix matching for predictions
- Maintaining per-buffer frequency data

**Key Functions (VimScript):**
```vim
wordpred#analyzer#UpdateFrequencies([bufnr])
wordpred#analyzer#GetWordFrequency(word, [bufnr])
wordpred#analyzer#GetBigramFrequency(word1, word2, [bufnr])
wordpred#analyzer#GetWordsWithPrefix(prefix, [bufnr])
wordpred#analyzer#GetBigramsWithPrefix(first_word, prefix, [bufnr])
wordpred#analyzer#Clear([bufnr])
wordpred#analyzer#GetStats([bufnr])
```

**Key Functions (Lua):**
```lua
require('wordpred.analyzer').update_frequencies([bufnr])
require('wordpred.analyzer').get_word_frequency(word, [bufnr])
require('wordpred.analyzer').get_bigram_frequency(word1, word2, [bufnr])
require('wordpred.analyzer').get_words_with_prefix(prefix, [bufnr])
require('wordpred.analyzer').get_bigrams_with_prefix(first_word, prefix, [bufnr])
require('wordpred.analyzer').clear([bufnr])
require('wordpred.analyzer').get_stats([bufnr])
```

### Prediction Engine Module

The prediction engine combines unigram and bigram models:
- Unigram predictions based on word frequency
- Bigram predictions based on previous word context
- Weighted scoring to prefer contextual predictions
- Case-insensitive matching with case preservation

**Key Functions:**
```vim
wordpred#predict#PredictWord(prefix, [bufnr], [prev_word])
wordpred#predict#PredictWordUnigram(prefix, [bufnr])
wordpred#predict#PredictWordBigram(prev_word, prefix, [bufnr])
wordpred#predict#GetCurrentPrediction()
wordpred#predict#GetPredictionInfo()
```

### Display Module

The display module handles visual presentation:
- Neovim: Uses virtual text (extmarks) for inline display
- Vim 8.1+: Uses text properties/match highlighting
- Graceful degradation for older versions
- Customizable highlight groups

**Key Functions:**
```vim
wordpred#display#Show(prediction_text)
wordpred#display#Hide()
wordpred#display#Accept()
wordpred#display#Update()
```

### Performance Module

The performance module provides optimization and monitoring:
- Debouncing and throttling for reduced CPU usage
- Performance profiling and statistics
- Large buffer detection and optimization
- Execution time measurement

**Key Functions:**
```vim
wordpred#performance#Debounce(func, delay_ms, key)
wordpred#performance#GetStats()
wordpred#performance#ShouldUpdate(bufnr)
wordpred#performance#IsBufferLarge(bufnr)
```

## Testing

### Running All Tests

```bash
cd tests
./run_tests.sh
```

### Running Individual Tests

**Analyzer Tests:**
```bash
vim -u NONE -S test_analyzer.vim        # VimScript
nvim --headless -u NONE -c "luafile test_analyzer_lua.lua"  # Lua
```

**Prediction Tests:**
```bash
vim -u NONE -S test_predict.vim
```

### Interactive Examples

```bash
vim -S tests/example_analyzer.vim
```

### Test Coverage

Current tests cover:
- ✓ Word extraction with minimum length (3+ chars)
- ✓ Case-insensitive frequency counting
- ✓ Bigram frequency counting
- ✓ Prefix matching for unigrams
- ✓ Prefix matching for bigrams
- ✓ Buffer change detection
- ✓ Data clearing
- ✓ Empty buffer handling
- ✓ Unigram prediction algorithm
- ✓ Bigram prediction algorithm
- ✓ Combined prediction with weighting
- ✓ Minimum prefix length filtering
- ✓ Bigram weight preference
- ✓ Prediction fallback logic

## Development Roadmap

See [word-prediction-vim.md](../word-prediction-vim.md) for the complete project plan.

### Phase 1: Core Functionality (MVP) - ✓ Completed
- ✓ Project structure and repository setup
- ✓ Frequency analyzer module with unigram and bigram support
- ✓ Prediction engine with weighted scoring
- ✓ Display module for Neovim (virtual text) and Vim 8+ (text properties)
- ✓ Main plugin integration with autocommands
- ✓ Comprehensive unit tests
- ✓ Interactive demo

### Phase 2: Polish and Optimization - ✓ Completed
- ✓ Performance profiling and monitoring
- ✓ Debouncing for display updates
- ✓ Large buffer optimization
- ✓ Configurable filetype filters
- ✓ Buffer-local enable/disable
- ✓ Advanced configuration guide

### Phase 3: Documentation and Polish - ✓ Completed
- ✓ Vim help documentation (`:help wordpred`)
- ✓ 650+ line comprehensive help file with 12 sections
- ✓ Help tags for navigation
- ✓ Usage examples document (12 practical scenarios)
- ✓ Changelog with version history
- ✓ Quick reference card
- ✓ Complete documentation suite

### Phase 4: Advanced Features (Future)
- [ ] Trigram model support
- [ ] Cross-buffer learning (project-wide frequencies)
- [ ] Persistence: save/load frequency models
- [ ] Multiple prediction candidates (cycling with keys)
- [ ] Integration with completion frameworks (nvim-cmp)
- [ ] Visual feedback for prediction source

## Requirements

### For Vim
- Vim 8.0+ (for text properties/popup windows)
- VimScript support

### For Neovim
- Neovim 0.5+ (for Lua API and extmarks)

## Contributing

This is an active development project. Contributions are welcome!

## License

MIT License

## Inspiration

Based on the word prediction feature from [TreeMk](https://github.com/jailop/treemk), a Qt-based Markdown editor.
