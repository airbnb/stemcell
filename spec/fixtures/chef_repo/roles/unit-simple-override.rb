name 'unit-simple-override'
description 'unit-simple-override'

override_attributes({
  'instance_metadata' => {
    'instance_type' => 'm3.xlarge',
    'security_groups' => [
      'all',
      'override'
    ],
    'tags' => {
      'tag1' => 'tag1_value_override',
      'tag3' => 'tag3_value',
    },
  },
})
