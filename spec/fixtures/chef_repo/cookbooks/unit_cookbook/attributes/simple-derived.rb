default['instance_metadata']['tags'] = { 'tag1' => 'tag1_value_attribute_default' }
tag1 = node['instance_metadata']['tags']['tag1']
default['instance_metadata']['tags']['derived_tag1'] = tag1
