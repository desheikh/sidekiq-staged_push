test:
	bundle exec rake

rubocop:
	bundle exec rubocop

setup:
	createdb sidekiq_staged_push_development 2>/dev/null || true
	createdb sidekiq_staged_push_test 2>/dev/null || true
	cd spec/dummy && bin/rails db:migrate

sidekiq:
	bin/sidekiq

enqueue:
	bin/enqueue
