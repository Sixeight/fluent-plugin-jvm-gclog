#
# in_jvm_gclog
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
require "jvm_gclog"

module Fluent

class JVMGCLogInput < TailInput
  Plugin.register_input('jvm_gclog', self)

  def configure_parser(conf)
    @parser = JVMGCLog.new
    @hostname = `hostname -s`.strip
  end

  def convert_line_to_event(line, es)
    begin
      line.chomp!  # remove \n
      record = @parser.parse(line)
      time = record.delete("time")
      record["host"] = @hostname
      if time && record
          es.add(time, record)
      else
        log.warn "pattern not match: #{line.inspect}"
      end
    rescue => e
      log.warn line.dump, :error => e.to_s
      log.debug_backtrace(e.backtrace)
    end
  end

  def parse_singleline(lines)
    es = MultiEventStream.new
    lines.each { |line|
      convert_line_to_event(line, es)
    }
    es
  end

  def receive_lines(lines, tail_watcher = nil)
    es = parse_singleline(lines)
    unless es.empty?
      tag = if @tag_prefix || @tag_suffix
              @tag_prefix + tail_watcher.tag + @tag_suffix
            else
              @tag
            end
      begin
        router.emit_stream(tag, es)
      rescue
        # ignore errors. Engine shows logs and backtraces.
      end
    end
  end
end

end
