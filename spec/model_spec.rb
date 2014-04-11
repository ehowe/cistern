require 'spec_helper'

describe "Cistern::Model" do

  it "should duplicate a model" do
    class DupSpec < Cistern::Model
      identity :id
      attribute :name
      attribute :properties
    end

    model = DupSpec.new(id: 1, name: "string", properties: {value: "something", else: "what"})
    duplicate = model.dup

    duplicate.should == model
    duplicate.should_not eql model

    model.name= "anotherstring"
    duplicate.name.should == "string"
  end

  context "attribute parsing" do
    class TypeSpec < Cistern::Model
      identity :id
      attribute :name, type: :string
      attribute :created_at, type: :time
      attribute :flag, type: :boolean
      attribute :list, type: :array
      attribute :number, type: :integer
      attribute :floater, type: :float
      attribute :butternut_id, squash: ["squash", "id"], type: :integer
      attribute :butternut_type, squash: ["squash", "type"]
      attribute :squash
      attribute :vegetable, aliases: "squash"
      attribute :custom, parser: lambda { |v, _| "X!#{v}" }
      attribute :default, default: "im a squash"

      attribute :same_alias_1, aliases: "nested"
      attribute :same_alias_2, aliases: "nested"

      attribute :same_alias_squashed_1, squash: ["nested", "attr_1"]
      attribute :same_alias_squashed_2, squash: ["nested", "attr_2"]
      attribute :same_alias_squashed_3, squash: ["nested", "attr_2"]

      def save
        requires :flag
      end
    end

    it "should parse string" do
      TypeSpec.new(name: 1).name.should == "1"
    end

    it "should parse time" do
      time = Time.now
      created_at = TypeSpec.new(created_at: time.to_s).created_at
      created_at.should be_a(Time)
      created_at.to_i.should == time.to_i
    end

    it "should parse boolean" do
      TypeSpec.new(flag: "false").flag.should be_false
      TypeSpec.new(flag: "true").flag.should be_true
      TypeSpec.new(flag: false).flag.should be_false
      TypeSpec.new(flag: true).flag.should be_true
      TypeSpec.new(flag: "0").flag.should be_false
      TypeSpec.new(flag: "1").flag.should be_true
      TypeSpec.new(flag: 0).flag.should be_false
      TypeSpec.new(flag: 1).flag.should be_true
      TypeSpec.new(flag: false).should_not be_flag
      TypeSpec.new(flag: true).should be_flag
    end

    it "should parse an array" do
      TypeSpec.new(list: []).list.should == []
      TypeSpec.new(list: "item").list.should == ["item"]
    end

    it "should parse a float" do
      TypeSpec.new(floater: "0.01").floater.should == 0.01
      TypeSpec.new(floater: 0.01).floater.should == 0.01
    end

    it "should use custom parser" do
      TypeSpec.new(custom: "15").custom.should == "X!15"
    end

    it "should squash, cast, alias an attribute and keep a vanilla reference" do
      # vanilla squash
      TypeSpec.new({"squash" => {"id" => "12", "type" => "fred"}}).butternut_type.should == "fred"
      TypeSpec.new({"squash" => {"id" => "12", "type" => nil}}).butternut_type.should be_nil
      TypeSpec.new({"squash" => nil}).butternut_type.should be_nil

      # composite processors: squash and cast
      TypeSpec.new({"squash" => {"id" => "12", "type" => "fred"}}).butternut_id.should == 12
      TypeSpec.new({"squash" => {"id" => nil, "type" => "fred"}}).butternut_id.should be_nil
      TypeSpec.new({"squash" => {"type" => "fred"}}).butternut_id.should be_nil

      # override intermediate processing
      TypeSpec.new({"squash" => {"id" => "12", "type" => "fred"}}).squash.should == {"id" => "12", "type" => "fred"}

      # alias of override
      TypeSpec.new({"squash" => {"id" => "12", "type" => "fred"}}).vegetable.should == {"id" => "12", "type" => "fred"}
    end

    it "should set a default value" do
      TypeSpec.new.default.should == "im a squash"
    end

    it "should override a default value" do
      TypeSpec.new(default: "now im a different squash").default.should == "now im a different squash"
    end

    context "allowing the same alias for multiple attributes" do
      it "should do so when not squashing" do
        type_spec = TypeSpec.new({"nested" => "bamboo"})
        type_spec.same_alias_1.should == "bamboo"
        type_spec.same_alias_2.should == "bamboo"
      end

      it "should do so when squashing" do
        type_spec = TypeSpec.new({"nested" => {"attr_1" => "bamboo", "attr_2" => "panda"}})
        type_spec.same_alias_squashed_1.should == "bamboo"
        type_spec.same_alias_squashed_2.should == "panda"
        type_spec.same_alias_squashed_3.should == "panda"
      end
    end

    it "should slice out unaccounted for attributes" do
      TypeSpec.new({"something" => {"id" => "12"}}).attributes.keys.should_not include("something")
    end

    describe "#requires" do
      it "should raise if attribute not provided" do
        lambda { TypeSpec.new({"connection" => "fake", "something" => {"id" => "12"}}).save }.should raise_exception(ArgumentError)
      end

      it "should raise if attribute is provided and is nil" do
        lambda { TypeSpec.new({"connection" => "fake", "custom" => nil}).save }.should raise_exception(ArgumentError)
      end
    end
  end

  context "attribute coverage info collecting", :coverage do
    class CoverageSpec < Cistern::Model
      identity :id

      attribute :used, type: :string
      attribute :unused, type: :string
    end

    let!(:obj) { CoverageSpec.new(used: "foo", unused: "bar") }

    before(:each) do
      CoverageSpec.attributes[:used][:coverage_hits] = 0
      obj.used.should == "foo" # once
      obj.used.should == "foo" # twice
    end

    it "should store the file path where the attribute was defined" do
      CoverageSpec.attributes[:used][:coverage_file].should == __FILE__
      CoverageSpec.attributes[:unused][:coverage_file].should == __FILE__
    end

    it "should store the line number where the attribute was defined" do
      src_lines = File.read(__FILE__).lines

      src_lines[CoverageSpec.attributes[:used][:coverage_line] - 1].should match(/attribute :used/)
      src_lines[CoverageSpec.attributes[:unused][:coverage_line] - 1].should match(/attribute :unused/)
    end

    it "should store how many times an attribute's reader is called" do
      CoverageSpec.attributes[:used][:coverage_hits].should == 2
      CoverageSpec.attributes[:unused][:coverage_hits].should == 0
    end
  end
end
