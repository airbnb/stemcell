name 'unit-simple-both'
description 'unit-simple-both'

default_attributes({
  'instance_metadata' => {
    'instance_type' => 'c1.xlarge',
    'security_groups' => [
      'all',
      'default'
    ],
    'tags' => {
      'tag1' => 'tag1_value_default',
      'tag2' => 'tag2_value',
    },
  },
})

override_attributes({
  'instance_metadata' => {
    'instance_type' => 'm3.xlarge',
    'security_groups' => [
      'override'
    ],
    'tags' => {
      'tag1' => 'tag1_value_override',
      'tag3' => 'tag3_value',
    },
  },
})
