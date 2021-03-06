require 'puppet/parameter/boolean'

Puppet::Type.newtype(:aws_db_security_group) do
  @doc = ""

  ensurable

  validate do
    required_properties = []
    required_properties.each do |property|
      # We check for both places so as to cover the puppet resource path as well
      if self[:ensure] == :present && self[property].nil? && self.provider.send(property) == :absent
        raise Puppet::Error, "In aws_db_security_group you must provide a value for #{property}"
      end
    end
  end
  newproperty(:db_security_group_arn) do
    desc ""
    validate do |value|
      true
    end
  end
  newproperty(:db_security_group_description) do
    desc ""
    validate do |value|
      true
    end
  end
  newproperty(:db_security_group_name) do
    desc ""
    validate do |value|
      true
    end
  end
  newproperty(:ec2_security_groups) do
    desc ""
    validate do |value|
      true
    end
  end
  newproperty(:filters, :array_matching => :all) do
    desc ""
    validate do |value|
      true
    end
  end
  newproperty(:ip_ranges) do
    desc ""
    validate do |value|
      true
    end
  end
  newproperty(:max_records) do
    desc ""
    validate do |value|
      true
    end
  end
  newproperty(:owner_id) do
    desc ""
    validate do |value|
      true
    end
  end
  newproperty(:tags, :array_matching => :all) do
    desc ""
    validate do |value|
      true
    end
  end
  newproperty(:vpc_id) do
    desc ""
    validate do |value|
      true
    end
  end

  newparam(:name) do
    isnamevar
    desc "The namevar for this resource in AWS"
    validate do |value|
      true
    end
  end

  newparam(:tags) do
    desc "Tags are required for all AWS resources in Puppet"
    validate do |value|
      true
    end
  end
end
