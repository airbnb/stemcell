name 'unit-inherit-both'
description 'unit-inherit-both'

default_attributes({
  'instance_metadata' => {
    'instance_type' => 'c1.xlarge',
    'security_groups' => [
      'all',
      'default',
    ],
    'tags' => {
      'tag1' => 'tag1_value_default',
      'tag3' => 'tag3_value_default',
      'tag4' => 'tag4_value',
    },
  },
})

override_attributes({
  'instance_metadata' => {
    'instance_type' => 'm3.xlarge',
    'security_groups' => [
      'all',
      'override',
    ],
    'tags' => {
      'tag1' => 'tag1_value_override',
      'tag3' => 'tag3_value_override',
      'tag5' => 'tag5_value',
    },
  },
})

run_list(
  "role[unit-inherit-base]",
)
