# encoding: utf-8
# This file is distributed under New Relic's license terms.
# See https://github.com/newrelic/rpm/blob/master/LICENSE for complete details.

require 'new_relic/agent/threading/agent_thread'
require 'new_relic/agent/threading/thread_profile'

module NewRelic
  module Agent
    module Commands

      class ThreadProfilerSession

        attr_accessor :profile

        def initialize(thread_profiling_service)
          @thread_profiling_service = thread_profiling_service
        end

        def self.is_supported?
          RUBY_VERSION >= "1.9.2"
        end

        def handle_start_command(agent_command)
          raise_unsupported_error unless self.class.is_supported?
          raise_already_started_error if running?
          start(agent_command)
        end

        def handle_stop_command(agent_command)
          report_data = agent_command.arguments.fetch("report_data", true)
          stop(report_data)
        end

        def start(agent_command)
          @profile = Threading::ThreadProfile.new(agent_command.arguments)

          # This should really be a per-client setting rather than a global
          # setting for whole ThreadProfilingService. We're relying here on the
          # fact that we are the only client to set the profile_agent_code
          # setting. This (at present) only an internal setting.
          profile_agent_code = agent_command.arguments.fetch('profile_agent_code', false)
          @thread_profiling_service.profile_agent_code = profile_agent_code

          @thread_profiling_service.add_client(@profile)
        end

        def stop(report_data)
          NewRelic::Agent.logger.debug("Stopping thread profile.")
          @profile.mark_done unless @profile.nil?
          @profile = nil if !report_data
        end

        def harvest
          profile = @profile
          @thread_profiling_service.profile_agent_code = false
          @profile = nil
          profile
        end

        def running?
          !@profile.nil?
        end

        def finished?
          @profile && @profile.finished?
        end

        private

        def raise_command_error(msg)
          NewRelic::Agent.logger.debug(msg)
          raise NewRelic::Agent::Commands::AgentCommandRouter::AgentCommandError.new(msg)
        end

        def raise_already_started_error
          msg = "Profile already in progress. Ignoring agent command to start another."
          raise_command_error(msg)
        end

        def raise_unsupported_error
          msg = <<-EOF
Thread profiling is only supported on 1.9.2 and greater versions of Ruby.
We detected running agents capable of profiling, but the profile started with
an agent running Ruby #{RUBY_VERSION}.

Profiling again might select an appropriate agent, but we recommend running a
consistent version of Ruby across your application for better results.
          EOF
          raise_command_error(msg)
        end

      end
    end
  end
end