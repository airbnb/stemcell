name 'unit-inherit-default'
description 'unit-inherit-default'

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

run_list(
  "role[unit-inherit-base]",
)
