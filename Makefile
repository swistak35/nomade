REPO_RUBY_VERSION = $(shell cat .ruby-version)

test:
	@bundle exec rspec spec

test-all:
	@RBENV_VERSION=$(REPO_RUBY_VERSION) bash testsuite.sh

lint:
	@gem install --no-document --conservative rubocop && rubocop -l
