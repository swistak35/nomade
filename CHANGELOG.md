# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

N/A

## [0.1.3] - 25/3/2020
- Make timeout configurable

## [0.1.2] - 06/3/2020
- Add exception class name to the messages array variable used in hooks.
- No longer run `exit(0)` when there is no modifications to make, this allows for chaining in the same deploy-script.
- Add a default hook on `Nomade::Hooks::DEPLOY_FAILED` that will print the error.

## [0.1.1] - 04/3/2020

### Changed
- Refactored HTTP-library a bit, making it easier to read and remove duplicate code.

## [0.1.0] - 04/3/2020

### Changed
- Added hook-functionality so we can print extra information or ping external services.
- Fixed a case where we didn't mark a rollback as a failure.
- No longer depend on the system having the Nomad executable installed, we're now only using the Nomad API
- Introduced tests with coverage support

## [0.0.5] - 26/2/2020

### Changed
- Now we run a capacity planning check before we deploy.

## [0.0.4] - 29/1/2020

### Changed
- Lower the amount of seconds we're lingering before promotion.
- Lower the default timeout from 9 minutes to 3 minutes.

## [0.0.3] - 26/11/2019

### Changed
- Only use HTTPS to connect to API if the endpoint are https-enabled [d35c28](https://github.com/kaspergrubbe/nomade/commit/d35c287026a57c8bafb286e7cc0f8d6c3f6db515)
- Update internal variable to be more generic when using templates [#2](https://github.com/kaspergrubbe/nomade/pull/2)
- Allow consumers to overwrite built-in logger [#3](https://github.com/kaspergrubbe/nomade/pull/3)
- Add random linger before promotion [e0e0a7bb](https://github.com/kaspergrubbe/nomade/commit/e0e0a7bbd6521f6d65da31db87bd4b447e65b7f1)

## [0.0.2] - 9/10/2019

### Added
- Add a Job URL to log [#1](https://github.com/kaspergrubbe/nomade/pull/1)

## [0.0.1] - 9/10/2019

### Added
- Initial hackish release
