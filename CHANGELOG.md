# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

N/A

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
