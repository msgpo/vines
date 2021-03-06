# encoding: UTF-8

require "test_helper"

describe Vines::Stream::Server::Ready do
  subject      { Vines::Stream::Server::Ready.new(stream, nil) }
  let(:stream) { MiniTest::Mock.new }

  SERVER_STANZAS = []

  before do
    def subject.to_stanza(node)
      Vines::Stanza.from_node(node, stream).tap do |stanza|
        def stanza.process
          SERVER_STANZAS << self
        end if stanza
      end
    end
  end

  after do
    SERVER_STANZAS.clear
  end

  it "processes a valid node" do
    EM.run {
      config = MiniTest::Mock.new
      config.expect(:local_jid?, true, [Vines::JID.new("romeo@verona.lit")])

      stream.expect(:config, config)
      stream.expect(:remote_domain, "wonderland.lit")
      stream.expect(:domain, "verona.lit")
      stream.expect(:user=, nil, [Vines::User.new(jid: "alice@wonderland.lit")])

      node = node(%(<message from="alice@wonderland.lit" to="romeo@verona.lit"/>))
      subject.node(node)
      assert_equal 1, SERVER_STANZAS.size
      assert stream.verify
      assert config.verify
      EM.stop
    }
  end

  it "raises unsupported-stanza-type stream error" do
    EM.run {
      node = node("<bogus/>")
      -> { subject.node(node) }.must_raise Vines::StreamErrors::UnsupportedStanzaType
      assert SERVER_STANZAS.empty?
      assert stream.verify
      EM.stop
    }
  end

  it "raises improper-addressing stream error when to address is missing" do
    EM.run {
      node = node(%(<message from="alice@wonderland.lit"/>))
      -> { subject.node(node) }.must_raise Vines::StreamErrors::ImproperAddressing
      assert SERVER_STANZAS.empty?
      assert stream.verify
      EM.stop
    }
  end

  it "raises jid-malformed stanza error when to address is invalid" do
    EM.run {
      node = node(%(<message from="alice@wonderland.lit" to=" "/>))
      -> { subject.node(node) }.must_raise Vines::StanzaErrors::JidMalformed
      assert SERVER_STANZAS.empty?
      assert stream.verify
      EM.stop
    }
  end

  it "raises improper-addressing stream error" do
    EM.run {
      node = node(%(<message to="romeo@verona.lit"/>))
      -> { subject.node(node) }.must_raise Vines::StreamErrors::ImproperAddressing
      assert SERVER_STANZAS.empty?
      assert stream.verify
      EM.stop
    }
  end

  it "raises jid-malformed stanza error for invalid from address" do
    EM.run {
      node = node(%(<message from=" " to="romeo@verona.lit"/>))
      -> { subject.node(node) }.must_raise Vines::StanzaErrors::JidMalformed
      assert SERVER_STANZAS.empty?
      assert stream.verify
      EM.stop
    }
  end

  it "raises invalid-from stream error" do
    EM.run {
      stream.expect(:remote_domain, "wonderland.lit")
      node = node(%(<message from="alice@bogus.lit" to="romeo@verona.lit"/>))
      -> { subject.node(node) }.must_raise Vines::StreamErrors::InvalidFrom
      assert SERVER_STANZAS.empty?
      assert stream.verify
      EM.stop
    }
  end

  it "raises host-unknown stream error" do
    EM.run {
      stream.expect(:remote_domain, "wonderland.lit")
      stream.expect(:domain, "verona.lit")
      node = node(%(<message from="alice@wonderland.lit" to="romeo@bogus.lit"/>))
      -> { subject.node(node) }.must_raise Vines::StreamErrors::HostUnknown
      assert SERVER_STANZAS.empty?
      assert stream.verify
      EM.stop
    }
  end

  private

  def node(xml)
    Nokogiri::XML(xml).root
  end
end
