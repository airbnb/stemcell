name 'unit-simple-default'
description 'unit-simple-default'

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
