require "rails_helper"

RSpec.describe "lib/solid/adapters/interface.rb" do
  it "defines callbacks, proxies and AlwaysEnabled against a sandboxed copy of the file" do
    sandbox = Module.new
    sandbox.const_set(:Solid, Module.new)
    sandbox.const_get(:Solid).const_set(:Adapters, Module.new)
    adapters = sandbox.const_get(:Solid).const_get(:Adapters)
    core = Module.new
    core.const_set(:Proxy, Module.new { const_set(:ClassMethods, Module.new) })
    core.const_set(:Config, Module.new { def self.interface_enabled = false })
    adapters.const_set(:Core, core)

    load Rails.root.join("lib/solid/adapters/interface.rb").to_s, sandbox

    interface = sandbox.const_get("Solid::Adapters::Interface")
    methods_from = interface.send(:const_get, :METHODS_FROM)
    disabled_interface = Module.new
    disabled_interface.const_set(:Methods, Module.new)
    interface.send(:const_get, :DEFINE)[disabled_interface, enabled: false]

    expect(methods_from[disabled_interface]).to eq(disabled_interface)
    stub_const("RUBY_VERSION", "2.6.9")
    expect(methods_from[disabled_interface]).to eq(disabled_interface::Methods)

    enabled_interface = Module.new
    enabled_interface.const_set(:Methods, Module.new)
    interface.send(:const_get, :DEFINE)[enabled_interface, enabled: true]
    expect(enabled_interface::Proxy.ancestors).to include(SimpleDelegator)
    expect(enabled_interface[Object.new]).to be_a(SimpleDelegator)

    adapter_interface = Module.new
    adapter_interface.include(interface)
    expect(adapter_interface.const_defined?(:Proxy, false)).to be(true)

    always_enabled = Module.new
    always_enabled.const_set(:Methods, Module.new)
    always_enabled.include(interface::AlwaysEnabled)
    expect(always_enabled::Proxy.ancestors).to include(SimpleDelegator)

    impl_class = Class.new
    enabled_interface.included(impl_class)
    enabled_interface.extended(Module.new)
    expect(disabled_interface::Proxy.new(:passthrough)).to eq(:passthrough)
  end
end
