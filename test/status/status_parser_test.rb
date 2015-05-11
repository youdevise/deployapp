$: << File.join(File.dirname(__FILE__), "..", "../lib")

require 'deployapp/status'
require 'deployapp/status_retriever'
require 'socket'
require 'net/http'
require 'test/unit'

class StatusParserTest < Test::Unit::TestCase
  def run_against_server(responses, &block)
    server = TCPServer.new(2002)
    @serverthread =  Thread.new {
      loop do
        client = server.accept
        begin
          req = client.recv(100)
          regex = Regexp.new(/GET (.+) HTTP/)
          resp = "nodata"
          urimatch = regex.match(req)
          if  urimatch
            uri = urimatch[1]
            resp = responses[uri] if !responses[uri].nil?
          end

          headers = ["HTTP/1.1 200 OK",
                     "Date: Tue, 14 Dec 2010 10:48:45 GMT",
                     "Server: Ruby",
                     "Content-Type: text/html; charset=iso-8859-1",
                     "Content-Length: #{resp.length}\r\n\r\n"].join("\r\n")

          client.puts headers
          client.puts resp
          client.close
        rescue e
        end
      end
    }
    begin
      block.call
    ensure
      server.close
      @serverthread.kill
    end
  end

  def test_retrieves_version
    run_against_server("/info/version" => "0.0.1.65") {
      retriever = DeployApp::StatusRetriever.new
      assert_equal "0.0.1.65", retriever.retrieve("http://localhost:2002").version
    }
  end

  def test_retrieves_health
    run_against_server("/info/health" => "ill") {
      retriever = DeployApp::StatusRetriever.new
      assert_equal "ill", retriever.retrieve("http://localhost:2002").health
    }
  end

  def test_stoppable_when_safe
    run_against_server("/info/stoppable" => "safe") {
      retriever = DeployApp::StatusRetriever.new
      assert retriever.retrieve("http://localhost:2002").stoppable?
    }
  end

  def test_not_stoppable_when_unwise
    run_against_server("/info/stoppable" => "unwise") {
      retriever = DeployApp::StatusRetriever.new
      assert !retriever.retrieve("http://localhost:2002").stoppable?
    }
  end
end
