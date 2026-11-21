# firecrawl-local: scrape, crawl, and map from one local binary. See docs/FIRECRAWL.md.

# cargo install root lives in ../_cli/firecrawl-local next to the dotfiles repo unless FIRECRAWL_LOCAL_ROOT is set
FIRECRAWL_ROOT := env('FIRECRAWL_LOCAL_ROOT', justfile_directory() / '..' / '_cli' / 'firecrawl-local')
FIRECRAWL_BIN := FIRECRAWL_ROOT / 'bin' / 'firecrawl-local'
FIRECRAWL_PORT := env('FIRECRAWL_PORT', '3002')

# install or update firecrawl-local into FIRECRAWL_ROOT and link it into ~/.local/bin (see docs/FIRECRAWL.md)
[group('FIRECRAWL')]
firecrawl-install:
	cargo install --locked --root "{{ FIRECRAWL_ROOT }}" firecrawl-local
	mkdir -p "{{ home_directory() }}/.local/bin"
	ln -sf "$(realpath "{{ FIRECRAWL_BIN }}")" "{{ home_directory() }}/.local/bin/firecrawl-local"
	firecrawl-local --version
alias install-firecrawl := firecrawl-install
alias firecrawl-update := firecrawl-install

# run the firecrawl-local cli (extra args go to the cli)
[group('FIRECRAWL')]
firecrawl *args:
	"{{ FIRECRAWL_BIN }}" {{ args }}

# serve the Firecrawl-compatible API on 127.0.0.1:FIRECRAWL_PORT (extra args go to serve)
[group('FIRECRAWL')]
firecrawl-serve port=FIRECRAWL_PORT *args:
	"{{ FIRECRAWL_BIN }}" serve --port {{ port }} {{ args }}

# scrape one page and print it as markdown
[group('FIRECRAWL')]
firecrawl-scrape url:
	"{{ FIRECRAWL_BIN }}" scrape {{ quote(url) }} --markdown

# crawl a site into a folder of pages (default: ./pages, 50 pages)
[group('FIRECRAWL')]
firecrawl-crawl url limit='50' out='./pages':
	"{{ FIRECRAWL_BIN }}" crawl {{ quote(url) }} --limit {{ limit }} --out {{ quote(out) }}

# list the urls of a site
[group('FIRECRAWL')]
firecrawl-map url:
	"{{ FIRECRAWL_BIN }}" map {{ quote(url) }}
