name 'unit-inherit-base'
description 'unit-inherit-base'

default_attributes({
  'instance_metadata' => {
    'instance_type' => 'm1.xlarge',
    'security_groups' => [
      'all',
      'base',
    ],
    'tags' => {
      'tag1' => 'tag1_value_base',
      'tag2' => 'tag2_value',
    },
  },
})

run_list(
  "role[unit-inherit-base]",
)
