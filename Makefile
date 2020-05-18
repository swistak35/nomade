test:
	@bundle exec rspec spec

test-all:
	@RBENV_VERSION=$(shell cat .ruby-version) bash testsuite.sh

lint:
	@gem install --no-document --conservative rubocop && rubocop -l
