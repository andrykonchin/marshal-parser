#!/usr/bin/env ruby

require 'marshal-cli'

Dry::CLI.new(MarshalCLI::CLI::Commands).call
