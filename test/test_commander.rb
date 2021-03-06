#!/usr/bin/env ruby
#MIT License
#Copyright (c) 2018 phR0ze
#
#Permission is hereby granted, free of charge, to any person obtaining a copy
#of this software and associated documentation files (the "Software"), to deal
#in the Software without restriction, including without limitation the rights
#to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#copies of the Software, and to permit persons to whom the Software is
#furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all
#copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#SOFTWARE.

require 'minitest/autorun'
require_relative '../lib/nub/sys'
require_relative '../lib/nub/core'
require_relative '../lib/nub/commander'

class TestCommander < Minitest::Test

  def setup
    Log.init(path:nil, queue: false, stdout: true)
    ARGV.clear
  end

  #-----------------------------------------------------------------------------
  # Test reduce expressions
  #-----------------------------------------------------------------------------
  def test_reduce_expressions
    app = 'reduce'
    examples = "Full ISO Build: sudo ./#{app} clean build all -p personal\n".colorize(:green)
    examples += "Rebuild initramfs: sudo ./#{app} clean build initramfs,iso -p personal\n".colorize(:green)
    examples += "Rebuild multiboot: sudo ./#{app} clean build multiboot,iso -p personal\n".colorize(:green)
    examples += "Clean pacman dbs: sudo ./#{app} clean --pacman\n".colorize(:green)
    examples += "Build k8snode deployment: sudo ./#{app} clean build iso -d k8snode -p personal\n".colorize(:green)
    examples += "Pack k8snode deployment: ./#{app} pack k8snode\n".colorize(:green)
    examples += "Deploy nodes: sudo ./#{app} deploy k8snode 10,11,12\n".colorize(:green)
    examples += "Deploy container: sudo ./#{app} deploy build --run\n".colorize(:green)

    cmdr = Commander.new(app:app, version:'0.0.1', examples:examples)
    cmdr.add_global('-p|--profile=PROFILE', 'Profile to use', type:String)
    cmdr.add('info', 'List build info')
    cmdr.add('list', 'List out components', nodes:[
      Option.new(nil, 'Components to list', type:Array, allowed:{
        all: 'List all components',
        boxes: 'List all boxes',
        isos: 'List all isos',
        images: 'List all docker images'
      }),
      Option.new('--raw', "Produce output suitable for automation"),
    ])
    cmdr.add('clean', 'Clean ISO components', nodes:[
      Option.new(nil, 'Components to clean', type:Array, allowed:{
        all: 'Clean all components including deployments',
        initramfs: 'Clean initramfs image',
        multiboot: 'Clean grub multiboot image',
        iso: 'Clean bootable ISO'
      }),
      Option.new('--pacman', "Clean pacman repos"),
      Option.new('--cache', "Clean pacman/ruby package cache"),
      Option.new('--vms', "Clean VMs that are no longer deployed"),
      Option.new('-d|--deployments=DEPLOYMENTS', "Deployments to clean", type:Array)
    ])
    cmdr.add('build', 'Build ISO components', nodes:[
      Option.new(nil, 'Components to build', type:Array, allowed:{
        all: 'Build all components including deployments',
        initramfs: 'Build initramfs image',
        multiboot: 'Build grub multiboot image',
        iso: 'Clean bootable ISO',
      }),
      Option.new('-d|--deployments=DEPLOYMENTS', "Deployments to build", type:Array)
    ])
    cmdr.add('pack', 'Pack ISO deployments into vagrant boxes', nodes:[
      Option.new(nil, "Deployments to pack", type:Array, required:true),
      Option.new('--disk-size=DISK_SIZE', "Set the disk size in MB e.g. 10000", type:String),
      Option.new('--force', "Pack the given deployment/s even if they already exist")
    ])
    cmdr.add('deploy', 'Deploy VMs or containers', nodes:[
      Option.new(nil, "Deployments to pack", type:Array, required:true),
      Option.new(nil, "Comma delimited list of last octet IPs (e.g. 10,11,12", type:Array),
      Option.new('-n|--name=NAME', "Give a name to the nodes being deployed", type:String),
      Option.new('-f|--force', "Deploy the given deployment/s even if they already exist"),
      Option.new('-r|--run', "Run the container with defaults"),
      Option.new('-e|--exec=CMD', "Specific command to run in container", type:String),
      Option.new('--ipv6', "Enable IPv6 on the given nodes"),
      Option.new('--vagrantfile', "Export the Vagrantfile only"),
    ])

    exp = "clean build all -p standard"
    ARGV.clear and ARGV.concat(exp.split(" "))
    Sys.capture{cmdr.parse!}
    assert_equal('standard', cmdr[:global][:profile])
    assert_equal(1, cmdr[:clean].size)
    assert_nil(cmdr[:clean][:pacman])
    assert_equal(['all'], cmdr[:clean][:clean0])
    assert_equal(1, cmdr[:build].size)
    assert_equal(['all'], cmdr[:build][:build0])

    exp = "clean build initramfs,iso -p standard"
    ARGV.clear and ARGV.concat(exp.split(" "))
    Sys.capture{cmdr.parse!}
    assert_equal('standard', cmdr[:global][:profile])
    assert_equal(['initramfs', 'iso'], cmdr[:clean][:clean0])
    assert_equal(['initramfs', 'iso'], cmdr[:build][:build0])

    # Test clean sub-command with positional required option given
    exp = "clean all --pacman"
    ARGV.clear and ARGV.concat(exp.split(" "))
    Sys.capture{cmdr.parse!}
    assert_equal(2, cmdr[:clean].size)
    assert(cmdr[:clean][:pacman])
    assert_equal(['all'], cmdr[:clean][:clean0])

    # Test clean sub-command with positional required option not given
    exp = "clean build initramfs,multiboot,iso -d k8snode -p standard"
    ARGV.clear and ARGV.concat(exp.split(" "))
    Sys.capture{cmdr.parse!}
    assert_equal('standard', cmdr[:global][:profile])
    assert_equal(2, cmdr[:clean].size)
    assert_equal(['k8snode'], cmdr[:clean][:deployments])
    assert_equal(['initramfs', 'multiboot', 'iso'], cmdr[:clean][:clean0])
    assert_equal(2, cmdr[:clean].size)
    assert_equal(['k8snode'], cmdr[:build][:deployments])
    assert_equal(['initramfs', 'multiboot', 'iso'], cmdr[:build][:build0])

    exp = "pack base,lite,heavy -p standard"
    ARGV.clear and ARGV.concat(exp.split(" "))
    Sys.capture{cmdr.parse!}
    assert_equal('standard', cmdr[:global][:profile])
    assert_equal(1, cmdr[:pack].size)
    assert_equal(['base', 'lite', 'heavy'], cmdr[:pack][:pack0])

    exp = "deploy k8snode 10,11,12 -n node -p standard"
    ARGV.clear and ARGV.concat(exp.split(" "))
    Sys.capture{cmdr.parse!}
    assert_equal('standard', cmdr[:global][:profile])
    assert_equal(3, cmdr[:deploy].size)
    assert_equal(['k8snode'], cmdr[:deploy][:deploy0])
    assert_equal(['10', '11', '12'], cmdr[:deploy][:deploy1])
    assert_equal('node', cmdr[:deploy][:name])

    exp = "deploy k8snode 10,11,12 --vagrantfile"
    ARGV.clear and ARGV.concat(exp.split(" "))
    Sys.capture{cmdr.parse!}
    assert_equal(3, cmdr[:deploy].size)
    assert_equal(['k8snode'], cmdr[:deploy][:deploy0])
    assert_equal(['10', '11', '12'], cmdr[:deploy][:deploy1])
    assert(cmdr[:deploy][:vagrantfile])

    exp = "deploy k8snode -r"
    ARGV.clear and ARGV.concat(exp.split(" "))
    Sys.capture{cmdr.parse!}
    assert_equal(2, cmdr[:deploy].size)
    assert_equal(['k8snode'], cmdr[:deploy][:deploy0])
    assert(cmdr[:deploy][:run])

    ARGV.clear and ARGV << 'deploy' << 'k8snode' << '-e' << 'curl www.google.com'
    Sys.capture{cmdr.parse!}
    assert_equal(2, cmdr[:deploy].size)
    assert_equal(['k8snode'], cmdr[:deploy][:deploy0])
    assert_equal('curl www.google.com', cmdr[:deploy][:exec])
  end

  #-----------------------------------------------------------------------------
  # Test sub-commands
  #-----------------------------------------------------------------------------
  def test_command_options_mixed_with_subcommands
    cmdr = Commander.new
    cmdr.add('clean', 'Clean ISO components', nodes:[
      Option.new(nil, 'Components to clean', type:Array,
        allowed:{all: nil, pacman: nil, 'pacman-all': nil, initramfs: nil, multiboot: nil, iso: nil, 'iso-full': nil, vms: nil}),
      Command.new('deployments', "Deployments to clean", nodes:[
        Option.new(nil, "Deployments to clean", type:Array, required:true)
      ])
    ])

    expected =<<EOF
Error: positional option required!
Deployments to clean

Usage: ./test_commander.rb clean deployments [options]
    deployments0                            Deployments to clean: Array(String), Required
    -h|--help                               Print command/options help: Flag(false)
EOF

    # Sub-command positional not satisified
    exp = "clean deployments"
    ARGV.clear and ARGV.concat(exp.split(" "))
    capture = Sys.capture{ assert_raises(SystemExit){ cmdr.parse! } }
    assert_equal(expected, capture.stdout.strip_color)

    # Command options before sub-command
    exp = "clean pacman,iso deployments x,y,z"
    ARGV.clear and ARGV.concat(exp.split(" "))
    cmdr.parse!
    assert_equal(['pacman', 'iso'], cmdr[:clean][:clean0])
    assert_equal(['x', 'y', 'z'], cmdr[:clean][:deployments][:deployments0])

    # Command options after sub-command
    exp = "clean deployments x,y,z pacman,iso"
    ARGV.clear and ARGV.concat(exp.split(" "))
    cmdr.parse!
    assert_equal(['pacman', 'iso'], cmdr[:clean][:clean0])
    assert_equal(['x', 'y', 'z'], cmdr[:clean][:deployments][:deployments0])
  end

  def test_subcommand_consumes_applicable_options_only
    cmdr = Commander.new
    cmdr.add('clean', 'Clean ISO components', nodes:[
      Option.new(nil, 'Components to clean', type:Array,
        allowed:{all: nil, pacman: nil, 'pacman-all': nil, initramfs: nil, multiboot: nil, iso: nil, 'iso-full': nil, vms: nil}),
      Command.new('deployments', "Deployments to clean", nodes:[
        Option.new(nil, "Deployments to clean", type:Array, required:true)
      ])
    ])

    exp = "clean deployments x,y,z pacman,iso"
    ARGV.clear and ARGV.concat(exp.split(" "))
    cmdr.parse!
    assert_equal(['pacman', 'iso'], cmdr[:clean][:clean0])
    assert_equal(['x', 'y', 'z'], cmdr[:clean][:deployments][:deployments0])
  end

  def test_subcommands_chained
    cmdr = Commander.new
    cmdr.add('build', 'Build components', nodes:[
      Command.new('iso', 'Build ISO'),
      Command.new('iso-full', 'Build Full ISO'),
      Command.new('initramfs', 'Build InitRamFS'),
      Command.new('multiboot', 'Build Multiboot'),
    ])

    # Test regular single command as named positional
    ARGV.clear and ARGV << 'build' << 'iso'
    cmdr.parse!
    assert_equal(1, cmdr[:build].size)
    assert(cmdr[:build][:iso])
    assert_equal(0, cmdr[:build][:iso].size)

    # Test chained case for multiple sub-commands (acting like named positionals)
    ARGV.clear and ARGV << 'build' << 'iso' << 'iso-full' << 'initramfs' << 'multiboot'
    cmdr.parse!
    assert_equal(4, cmdr[:build].size)
    assert(cmdr[:build][:iso])
    assert(cmdr[:build][:iso_full])
    assert(cmdr[:build][:initramfs])
    assert(cmdr[:build][:multiboot])
  end

  def test_subcommand_named_options
    expected =<<EOF
Error: invalid named option '-s'!
Enable features

Usage: ./test_commander.rb enable [commands] [options]
COMMANDS:
    foo                                     Feature foo
OPTIONS:
    -h|--help                               Print command/options help: Flag(false)

see './test_commander.rb enable COMMAND --help' for specific command help
EOF
    cmdr = Commander.new
    cmdr.add('enable', 'Enable features', nodes:[
      Command.new('foo', 'Feature foo', nodes:[
        Option.new('-b|--build=COMP', 'Build component', type:String),
        Option.new('-d|--debug', 'Debug foo'),
      ])
    ])

    # Check that sub-command isn't set with bad arg
    ARGV.clear and ARGV << 'enable' << 'foo' << '-s'
    capture = Sys.capture{ assert_raises(SystemExit){ cmdr.parse! } }
    assert_equal(expected, capture.stdout.strip_color)

    # Check that sub-command positional works
    ARGV.clear and ARGV << 'enable' << 'foo' << '-d' << '-b' << 'bar'
    cmdr.parse!
    assert_equal(1, cmdr[:enable].size)
    assert_equal(2, cmdr[:enable][:foo].size)
    assert_equal('bar', cmdr[:enable][:foo][:build])
    assert_equal(TrueClass, cmdr[:enable][:foo][:debug].class)
  end

  def test_subcommand_positional_options
    expected =<<EOF
Error: invalid positional option 'bar'!
Enable features

Usage: ./test_commander.rb enable [commands] [options]
COMMANDS:
    foo                                     Feature foo
OPTIONS:
    -h|--help                               Print command/options help: Flag(false)

see './test_commander.rb enable COMMAND --help' for specific command help
EOF
    cmdr = Commander.new
    cmdr.add('enable', 'Enable features', nodes:[
      Command.new('foo', 'Feature foo', nodes:[
        Option.new(nil, 'Foo positional option', allowed:{bar: nil})
      ])
    ])

    # Check that sub-command isn't set with bad arg
    ARGV.clear and ARGV << 'enable' << 'bar'
    capture = Sys.capture{ assert_raises(SystemExit){ cmdr.parse! } }
    assert_equal(expected, capture.stdout.strip_color)

    # Check that sub-command positional works
    ARGV.clear and ARGV << 'enable' << 'foo' << 'bar'
    cmdr.parse!
    assert_equal(1, cmdr[:enable].size)
    assert_equal(1, cmdr[:enable][:foo].size)
    assert_equal('bar', cmdr[:enable][:foo][:foo0])
  end

  def test_subcommand_no_options
    cmdr = Commander.new
    cmdr.add('enable', 'Enable features', nodes:[
      Command.new('foo', 'Feature foo')
    ])

    # Check that nothing is set yet
    assert_nil(cmdr[:enable])

    # Check that the enable comamnd is set but nothing else
    ARGV.clear and ARGV << 'enable'
    cmdr.parse!
    assert(cmdr[:enable].class == Hash && !cmdr[:enable].any?)

    # Check that the sub-command is set properly
    ARGV.clear and ARGV << 'enable' << 'foo'
    cmdr.parse!
    assert(cmdr[:enable][:foo].class == Hash)
  end

  #-----------------------------------------------------------------------------
  # Test global options
  #-----------------------------------------------------------------------------
  def test_global_named_with_value
    ARGV.clear and ARGV << '-c' << 'foo'
    cmdr = Commander.new
    cmdr.add_global('-c|--cluster=CLUSTER', 'Name of the cluster to use', type:String)
    cmdr.parse!
    assert(cmdr.key?(:global))
    assert_equal("foo", cmdr[:global][:cluster])
  end

  def test_global_always_exists
    ARGV.clear and ARGV << 'build' << 'foo'
    cmdr = Commander.new
    cmdr.add('build', 'Build components', nodes:[
      Option.new(nil, 'Component to build', required:true)
    ])
    cmdr.parse!
    assert(cmdr.key?(:global))
  end

  def test_global_set_multiple
    ARGV.clear and ARGV << '-d' << '--skip'
    cmdr = Commander.new
    cmdr.add_global('-d|--debug', 'Debug')
    cmdr.add_global('-s|--skip', 'Skip')
    cmdr.parse!
    assert(cmdr[:global][:debug])
    assert(cmdr[:global][:skip])
  end

  def test_global_positional_is_not_command
    expected =<<EOF
Error: positional option required!
Global options:
    global0                                 Super foo bar: String, Required
    -h|--help                               Print command/options help: Flag(false)
EOF
    ARGV.clear and ARGV << 'build'
    cmdr = Commander.new
    cmdr.add_global(nil, 'Super foo bar', required:true)
    cmdr.add('build', 'Build components')
    capture = Sys.capture{ assert_raises(SystemExit){ cmdr.parse! }}
    assert_equal(expected, capture.stdout.strip_color)
  end

  def test_global_positional_set
    ARGV.clear and ARGV << 'foobar'
    cmdr = Commander.new
    cmdr.add_global(nil, 'Super foo bar')
    cmdr.parse!
    assert_equal("foobar", cmdr[:global][:global0])
  end

  def test_global_named_set_in_middle
    ARGV.clear and ARGV << 'build' << '-d' << 'clean'
    cmdr = Commander.new
    cmdr.add_global('-d|--debug', 'Debug')
    cmdr.add('clean', 'Clean components')
    cmdr.add('build', 'Build components')
    cmdr.parse!
    assert(cmdr[:global][:debug])
    assert(cmdr[:build])
    assert(cmdr[:clean])
  end

  def test_global_named_at_end
    ARGV.clear and ARGV << 'build' << '-d'
    cmdr = Commander.new
    cmdr.add_global('-d|--debug', 'Debug')
    cmdr.add('build', 'Build components')
    cmdr.parse!
    assert(cmdr[:global][:debug])
    assert(cmdr[:build])
  end

  def test_global_named_at_begining
    ARGV.clear and ARGV << '-d' << 'build'
    cmdr = Commander.new
    cmdr.add_global('-d|--debug', 'Debug')
    cmdr.add('build', 'Build components')
    cmdr.parse!
    assert(cmdr[:global][:debug])
    assert(cmdr[:build])
  end

  def test_take_globals_at_begining_nothing_else
    ARGV.clear and ARGV << '-d'
    cmdr = Commander.new
    cmdr.add_global('-d|--debug', 'Debug')
    cmdr.send(:move_globals_to_front!)
  end

  def test_global_is_reserved_command
    cmdr = Commander.new
    capture = Sys.capture{ assert_raises(SystemExit){
      cmdr.add('global', 'global is reserved')
    }}
    assert_equal("Error: 'global' is a reserved command name!\n", capture.stdout.strip_color)
  end

  def test_global_named_help_with_banner
    expected =<<EOF
test_v0.0.1
--------------------------------------------------------------------------------
Usage: ./test [commands] [options]
Global options:
    -d|--debug                              Debug: Flag(false)
    -h|--help                               Print command/options help: Flag(false)
COMMANDS:

see './test COMMAND --help' for specific command help
EOF
    ARGV.clear and ARGV << '-h'
    cmdr = Commander.new(app:'test', version:'0.0.1')
    cmdr.add_global('-d|--debug', 'Debug')
    capture = Sys.capture{ assert_raises(SystemExit){ cmdr.parse! } }
    assert_equal(expected, capture.stdout.strip_color)
  end

  def test_global_named_help_no_banner
    expected =<<EOF
Usage: ./test_commander.rb [commands] [options]
Global options:
    -d|--debug                              Debug: Flag(false)
    -h|--help                               Print command/options help: Flag(false)
COMMANDS:

see './test_commander.rb COMMAND --help' for specific command help
EOF
    cmdr = Commander.new
    cmdr.add_global('-d|--debug', 'Debug')
    capture = Sys.capture{ assert_raises(SystemExit){ cmdr.parse! } }
    assert_equal(expected, capture.stdout)
  end

  def test_global_positional_help_no_banner
    expected =<<EOF
Usage: ./test_commander.rb [commands] [options]
Global options:
    global0                                 Global positional: String
    -d|--debug                              Debug: Flag(false)
    -h|--help                               Print command/options help: Flag(false)
COMMANDS:

see './test_commander.rb COMMAND --help' for specific command help
EOF
    cmdr = Commander.new
    cmdr.add_global(nil, 'Global positional')
    cmdr.add_global('-d|--debug', 'Debug')
    capture = Sys.capture{ assert_raises(SystemExit){ cmdr.parse! } }
    assert_equal(expected, capture.stdout)
  end

  #-----------------------------------------------------------------------------
  # Test required and mixed options
  #-----------------------------------------------------------------------------
  def test_required_named_option_missing
    expected =<<EOF
Error: required option -c|--comp not given!
Build components

Usage: ./test_commander.rb build [options]
    -c|--comp                               Component to build: Flag(false), Required
    -h|--help                               Print command/options help: Flag(false)
EOF
    ARGV.clear and ARGV << 'build'
    cmdr = Commander.new
    cmdr.add('build', 'Build components', nodes:[
      Option.new('-c|--comp', 'Component to build', required:true)
    ])
    capture = Sys.capture{ assert_raises(SystemExit){ cmdr.parse! } }
    assert_equal(expected, capture.stdout.strip_color)
  end

  def test_multi_positional_and_named_options
    ARGV.clear and ARGV << 'delete' << 'deployment' << 'tron' << '-n' << 'trondom'
    cmdr = Commander.new(app:'test', version:'0.0.1')
    cmdr.add('delete', 'Delete the given component', nodes:[
      Option.new(nil, 'Component type'),
      Option.new(nil, 'Component name'),
      Option.new('-n|--namespace=NAMESPACE', 'Namespace to use', type:String),
    ])
    out = Sys.capture{ cmdr.parse! }.stdout.split("\n").map{|x| x.strip_color}
    assert(out.size == 2 && out.include?("test_v0.0.1"))
    assert_equal('deployment', cmdr[:delete][:delete0])
    assert_equal('tron', cmdr[:delete][:delete1])
    assert_equal('trondom', cmdr[:delete][:namespace])
  end

  #-----------------------------------------------------------------------------
  # Test chained commands
  #-----------------------------------------------------------------------------
  def test_diff_allowed_option_values
    cmdr = Commander.new
    cmdr.add('clean', 'Clean ISO components', nodes:[
      Option.new(nil, 'Components to clean', type:Array, allowed:{ iso: nil, initramfs: nil, pacman: nil}),
    ])
    cmdr.add('build', 'Build ISO components', nodes:[
      Option.new(nil, 'Components to build', type:Array, allowed:{iso: '2', initramfs: '1'})
    ])

    exp = "clean pacman,initramfs,iso"
    ARGV.clear and ARGV.concat(exp.split(" "))
    cmdr.parse!
    assert_equal(1, cmdr[:clean].size)
    assert_equal(['pacman', 'initramfs', 'iso'], cmdr[:clean][:clean0])

    exp = "build initramfs,iso"
    ARGV.clear and ARGV.concat(exp.split(" "))
    cmdr.parse!
    assert_equal(1, cmdr[:build].size)
    assert_equal(['initramfs', 'iso'], cmdr[:build][:build0])

    expected =<<EOF
Error: invalid array value 'pacman'!
Build ISO components

Usage: ./test_commander.rb build [options]
    build0                                  Components to build: Array(String)
                                              initramfs: 1
                                              iso: 2
    -h|--help                               Print command/options help: Flag(false)
EOF
    exp = "clean build pacman,initramfs,iso"
    ARGV.clear and ARGV.concat(exp.split(" "))
    capture = Sys.capture{assert_raises(SystemExit){cmdr.parse!}}
    assert_equal(expected, capture.stdout.strip_color)
  end

  def test_expand_chained_options
    ARGV.clear and ARGV << 'clean' << 'build' << 'foo'
    cmdr = Commander.new
    cmdr.add('clean', 'Clean components', nodes:[
      Option.new(nil, 'Component to clean', required: true)
    ])
    cmdr.add('build', 'Build components', nodes:[
      Option.new(nil, 'Component to build', required: true)
    ])
    cmdr.send(:expand_chained_options!)
    assert_equal(["clean", "foo", "build", "foo"], ARGV)

    ARGV.clear and ARGV << 'clean' << 'foo' << 'build' << 'foo'
    cmdr.send(:expand_chained_options!)
    assert_equal(["clean", "foo", "build", "foo"], ARGV)
  end

  def test_chained_named
    ARGV.clear and ARGV << 'build' << 'publish' << '--comp'
    cmdr = Commander.new
    cmdr.add('build', 'Build components', nodes:[
      Option.new('-c|--comp', 'Component to build', required:true)
    ])
    cmdr.add('publish', 'Publish components', nodes:[
      Option.new('-c|--comp', 'Component to publish', required:true)
    ])
    cmdr.parse!
    assert(cmdr[:build][:comp])
    assert(cmdr[:publish][:comp])
  end

  def test_chained_named_inconsistent_types
expected =<<EOF
Error: named option '--comp' value not found!
Build components

Usage: ./test_commander.rb build [options]
    -c|--comp=COMPONENT                     Component to build: Array(String), Required
    -h|--help                               Print command/options help: Flag(false)
EOF
    cmdr = Commander.new
    cmdr.add('build', 'Build components', nodes:[
      Option.new('-c|--comp=COMPONENT', 'Component to build', required:true, type:Array)
    ])
    cmdr.add('publish', 'Publish components', nodes:[
      Option.new('-c|--comp=COMPONENT', 'Component to publish', required:true, type:String)
    ])

    ARGV.clear and ARGV << 'build' << 'publish' << '--comp'
    capture = Sys.capture{ assert_raises(SystemExit){ cmdr.parse! } }
    assert_equal(expected, capture.stdout.strip_color)
  end

  def test_chained_positional_inconsistent_numbers_bad
expected =<<EOF
Error: invalid positional option 'extra'!
Publish components

Usage: ./test_commander.rb publish [options]
    publish0                                Component to publish: String, Required
    -h|--help                               Print command/options help: Flag(false)
EOF

    ARGV.clear and ARGV << 'build' << 'publish' << 'debug' << 'extra'
    cmdr = Commander.new
    cmdr.add('build', 'Build components', nodes:[
      Option.new(nil, 'Component to build', required:true),
      Option.new(nil, 'Extra positional', required:true)
    ])
    cmdr.add('publish', 'Publish components', nodes:[
      Option.new(nil, 'Component to publish', required:true)
    ])
    capture = Sys.capture{ assert_raises(SystemExit){ cmdr.parse! } }
    assert_equal(expected, capture.stdout.strip_color)
  end

  def test_chained_positional_inconsistent_numbers_good
    ARGV.clear and ARGV << 'build' << 'publish' << 'debug' << 'extra'
    cmdr = Commander.new
    cmdr.add('build', 'Build components', nodes:[
      Option.new(nil, 'Component to build', required:true)
    ])
    cmdr.add('publish', 'Publish components', nodes:[
      Option.new(nil, 'Component to publish', required:true),
      Option.new(nil, 'Extra positional', required:true)
    ])
    cmdr.parse!
    assert_equal("debug", cmdr[:build][:build0])
    assert_nil(cmdr[:build][:build1])
    assert_equal("debug", cmdr[:publish][:publish0])
    assert_equal("extra", cmdr[:publish][:publish1])
  end

  def test_chained_positional
    ARGV.clear and ARGV << 'build' << 'publish' << 'deploy' << 'debug'
    cmdr = Commander.new
    cmdr.add('build', 'Build components', nodes:[Option.new(nil, 'Component to build', required:true)])
    cmdr.add('publish', 'Publish components', nodes:[Option.new(nil, 'Component to publish', required:true)])
    cmdr.add('deploy', 'Deploy components', nodes:[Option.new(nil, 'Component to deply', required:true)])
    cmdr.parse!
    assert_equal("debug", cmdr[:build][:build0])
    assert_equal("debug", cmdr[:publish][:publish0])
    assert_equal("debug", cmdr[:deploy][:deploy0])
  end

  #-----------------------------------------------------------------------------
  # Test commands with named options
  #-----------------------------------------------------------------------------
  def test_named_option_long_quotes_equal
    ARGV.clear and ARGV << 'bar' << '--foobar=foo foo'
    cmdr = Commander.new(app:'test', version:'0.0.1')
    cmdr.add('bar', 'bar it up', nodes:[
      Option.new('-f|--foobar=FOOBAR', 'Set foo', type:String),
    ])
    out = Sys.capture{ cmdr.parse! }.stdout.split("\n").map{|x| x.strip_color}
    assert(out.size == 2 && out.include?("test_v0.0.1"))
    assert_equal('foo foo', cmdr[:bar][:foobar])
  end

  def test_named_option_long_array_equal
    ARGV.clear and ARGV << 'bar' << '--foobar' << 'foo1,foo2,foo3'
    cmdr = Commander.new
    cmdr.add('bar', 'bar it up', nodes:[
      Option.new('-f|--foobar=FOOBAR', 'Set foo', allowed:{foo1: nil, foo2: nil, foo3: nil}, type:Array),
    ])
    assert(Sys.capture{ cmdr.parse! }.stdout.empty?)
    assert_equal(['foo1', 'foo2', 'foo3'], cmdr[:bar][:foobar])
  end

  def test_named_option_long_array_equal
    ARGV.clear and ARGV << 'bar' << '--foobar=foo1,foo2,foo3'
    cmdr = Commander.new
    cmdr.add('bar', 'bar it up', nodes:[
      Option.new('-f|--foobar=FOOBAR', 'Set foo', allowed:{foo1: nil, foo2: nil, foo3: nil}, type:Array),
    ])
    assert(Sys.capture{ cmdr.parse! }.stdout.empty?)
    assert_equal(['foo1', 'foo2', 'foo3'], cmdr[:bar][:foobar])
  end

  def test_named_option_short_array
    ARGV.clear and ARGV << 'bar' << '-f' << 'foo1,foo2,foo3'
    cmdr = Commander.new
    cmdr.add('bar', 'bar it up', nodes:[
      Option.new('-f|--foobar=FOOBAR', 'Set foo', allowed:{foo1: nil, foo2: nil, foo3: nil}, type:Array),
    ])
    assert(Sys.capture{ cmdr.parse! }.stdout.empty?)
    assert_equal(['foo1', 'foo2', 'foo3'], cmdr[:bar][:foobar])
  end

  def test_named_option_long_string_equal
    ARGV.clear and ARGV << 'bar' << '--foobar=foo'
    cmdr = Commander.new
    cmdr.add('bar', 'bar it up', nodes:[
      Option.new('-f|--foobar=FOOBAR', 'Set foo', allowed:{foo: nil}, type:String),
    ])
    assert(Sys.capture{ cmdr.parse! }.stdout.empty?)
    assert_equal("foo", cmdr[:bar][:foobar])
  end

  def test_named_option_long_string
    ARGV.clear and ARGV << 'bar' << '--foobar' << 'foo'
    cmdr = Commander.new
    cmdr.add('bar', 'bar it up', nodes:[
      Option.new('-f|--foobar=FOOBAR', 'Set foo', allowed:{foo: nil}, type:String),
    ])
    assert(Sys.capture{ cmdr.parse! }.stdout.empty?)
    assert_equal("foo", cmdr[:bar][:foobar])
  end

  def test_named_option_short_string
    ARGV.clear and ARGV << 'bar' << '-f' << 'foo'
    cmdr = Commander.new(app:'test', version:'0.0.1')
    cmdr.add('bar', 'bar it up', nodes:[
      Option.new('-f|--foobar=FOOBAR', 'Set foo', allowed:{foo: nil}, type:String),
    ])
    out = Sys.capture{ cmdr.parse! }.stdout.split("\n").map{|x| x.strip_color}
    assert(out.size == 2 && out.include?("test_v0.0.1"))
    assert_equal("foo", cmdr[:bar][:foobar])
  end

  def test_named_option_long_int_equal
    ARGV.clear and ARGV << 'clean' << '--min=3'
    cmdr = Commander.new(app:'test', version:'0.0.1')
    cmdr.add('clean', 'Clean components', nodes:[
      Option.new(nil, 'Clean given components', allowed:{all: nil, iso: nil}, type:Array),
      Option.new('-d|--debug', 'Debug mode'),
      Option.new('-m|--min=MINIMUM', 'Set the minimum clean', allowed:{1 => nil, 2 => nil, 3 => nil}, type:Integer),
      Option.new('-s|--skip=COMPONENTS', 'Skip the given components', allowed:{iso: nil, image: nil}, type:Array)
    ])
    out = Sys.capture{ cmdr.parse! }.stdout.split("\n").map{|x| x.strip_color}
    assert(out.size == 2 && out.include?("test_v0.0.1"))
    assert_equal(3, cmdr[:clean][:min])
  end

  def test_named_option_long_int
    ARGV.clear and ARGV << 'clean' << '--min' << '3'
    cmdr = Commander.new
    cmdr.add('clean', 'Clean components', nodes:[
      Option.new(nil, 'Clean given components', allowed:{all: nil, iso: nil}, type:Array),
      Option.new('-d|--debug', 'Debug mode'),
      Option.new('-m|--min=MINIMUM', 'Set the minimum clean', allowed:{1 => nil, 2 => nil, 3 => nil}, type:Integer),
      Option.new('-s|--skip=COMPONENTS', 'Skip the given components', allowed:{iso: nil, image: nil}, type:Array)
    ])
    assert(Sys.capture{ cmdr.parse! }.stdout.empty?)
    assert_equal(3, cmdr[:clean][:min])
    assert_nil(cmdr[:clean][:debug])
    assert_nil(cmdr[:clean][:skip])
    assert_nil(cmdr[:clean][:clean0])
  end

  def test_named_option_short_invalid_int
    ARGV.clear and ARGV << 'clean' << '-m' << '4'
    cmdr = Commander.new
    cmdr.add('clean', 'Clean components', nodes:[
      Option.new('-m|--min=MINIMUM', 'Set the minimum clean', allowed:{1 => nil, 2 => nil, 3 => nil}, type:Integer),
    ])
    capture = Sys.capture{ assert_raises(SystemExit){ cmdr.parse! } }
    assert(capture.stdout.include?("Error: invalid integer value '4'"))
    assert(capture.stdout.include?("Set the minimum"))
  end

  def test_named_option_short_int
    ARGV.clear and ARGV << 'clean' << '-m' << '1'
    cmdr = Commander.new
    cmdr.add('clean', 'Clean components', nodes:[
      Option.new(nil, 'Clean given components', allowed:{all: nil, iso: nil}, type:Array),
      Option.new('-d|--debug', 'Debug mode'),
      Option.new('-m|--min=MINIMUM', 'Set the minimum clean', allowed:{1 => nil, 2 => nil, 3 => nil}, type:Integer),
      Option.new('-s|--skip=COMPONENTS', 'Skip the given components', allowed:{iso: nil, image: nil}, type:Array)
    ])
    assert(Sys.capture{ cmdr.parse! }.stdout.empty?)
    assert_equal(1, cmdr[:clean][:min])
    assert_nil(cmdr[:clean][:debug])
    assert_nil(cmdr[:clean][:skip])
    assert_nil(cmdr[:clean][:clean0])
  end

  def test_named_option_long_flag
    ARGV.clear and ARGV << 'clean' << '--debug'
    cmdr = Commander.new(app:'test', version:'0.0.1')
    cmdr.add('clean', 'Clean components', nodes:[
      Option.new('-d|--debug', 'Debug mode'),
    ])
    out = Sys.capture{ cmdr.parse! }.stdout.split("\n").map{|x| x.strip_color}
    assert(out.size == 2 && out.include?("test_v0.0.1"))
    assert_equal(true, cmdr[:clean][:debug])
  end

  def test_named_option_short_flag
    ARGV.clear and ARGV << 'clean' << '-d'
    cmdr = Commander.new
    cmdr.add('clean', 'Clean components', nodes:[
      Option.new(nil, 'Clean given components', allowed:{all: nil, iso: nil}, type:Array),
      Option.new('-d|--debug', 'Debug mode'),
      Option.new('-m|--min=MINIMUM', 'Set the minimum clean', allowed:{1 => nil, 2 => nil, 3 => nil}, type:Integer),
      Option.new('-s|--skip=COMPONENTS', 'Skip the given components', allowed:{iso: nil, image: nil}, type:Array)
    ])
    assert(Sys.capture{ cmdr.parse! }.stdout)
    assert_equal(true, cmdr[:clean][:debug])
    assert_nil(cmdr[:clean][:min])
    assert_nil(cmdr[:clean][:skip])
    assert_nil(cmdr[:clean][:clean0])
  end

  #-----------------------------------------------------------------------------
  # Test commands with positional options
  #-----------------------------------------------------------------------------
  def test_optional_positionals
    ARGV.clear and ARGV << 'build'
    cmdr = Commander.new
    cmdr.add('build', 'Build components', nodes:[
      Option.new(nil, 'Component to build')
    ])
    cmdr.parse!
    assert(cmdr[:build])
    assert(!cmdr[:build][:build0])
  end

  def test_positional_integer_good
    ARGV.clear and ARGV << 'clean' << '3'
    cmdr = Commander.new(app:'test', version:'0.0.1')
    cmdr.add('clean', 'Clean components', nodes:[
      Option.new(nil, 'Clean given components', allowed:{1 => nil, 3 => nil}, type:Integer)
    ])
    out = Sys.capture{ cmdr.parse! }.stdout.split("\n").map{|x| x.strip_color}
    assert(out.size == 2 && out.include?("test_v0.0.1"))
    assert_equal(3, cmdr[:clean][:clean0])
  end

  def test_positional_invalid_integer_value
    ARGV.clear and ARGV << 'clean' << '2'
    cmdr = Commander.new
    cmdr.add('clean', 'Clean components', nodes:[
      Option.new(nil, 'Clean given components', allowed:{1 => nil, 3 => nil}, type:Integer)
    ])
    capture = Sys.capture{ assert_raises(SystemExit){ cmdr.parse! } }
    assert(capture.stdout.include?("Error: invalid integer value '2'"))
    assert(capture.stdout.include?("clean0"))
  end

  def test_positional_array_good
    ARGV.clear and ARGV << 'clean' << 'all'
    cmdr = Commander.new
    cmdr.add('clean', 'Clean components', nodes:[
      Option.new(nil, 'Clean given components', allowed:{all: nil, iso: nil}, type:Array)
    ])
    out = Sys.capture{ cmdr.parse! }
    assert_equal("", out.stdout) # no output for succcess without app name
    assert_equal(["all"], cmdr[:clean][:clean0])
  end

  def test_positional_invalid_array_value
    ARGV.clear and ARGV << 'clean' << 'foo'
    cmdr = Commander.new
    cmdr.add('clean', 'Clean components', nodes:[
      Option.new(nil, 'Clean given components', allowed:{all: nil, iso: nil}, type:Array)
    ])
    capture = Sys.capture{assert_raises(SystemExit){cmdr.parse!}}
    assert(capture.stdout.include?("Error: invalid array value 'foo'"))
    assert(capture.stdout.include?("clean0"))
  end

  def test_positional_invalid_string_value
    ARGV.clear and ARGV << 'clean' << 'foo'
    cmdr = Commander.new
    cmdr.add('clean', 'Clean components', nodes:[
      Option.new(nil, 'Clean given components', allowed:{all: nil, iso: nil})
    ])
    capture = Sys.capture{assert_raises(SystemExit){cmdr.parse!}}
    assert(capture.stdout.include?("Error: invalid string value 'foo'"))
    assert(capture.stdout.include?("clean0"))
  end

  def test_positional_option_too_many
    ARGV.clear and ARGV << 'clean' << 'foo' << 'bar'
    cmdr = Commander.new
    cmdr.add('clean', 'Clean components', nodes:[
      Option.new(nil, 'Clean given components')
    ])
    capture = Sys.capture{assert_raises(SystemExit){cmdr.parse!}}
    assert(capture.stdout.include?("Error: invalid positional option 'bar'"))
    assert(capture.stdout.include?("clean0"))
  end

  def test_positional_option_not_given
    ARGV.clear and ARGV << 'clean'
    cmdr = Commander.new
    cmdr.add('clean', 'Clean components', nodes:[
      Option.new(nil, 'Clean given components', required:true)
    ])
    capture = Sys.capture{assert_raises(SystemExit){cmdr.parse!}}
    assert(capture.stdout.include?("Error: positional option required"))
    assert(capture.stdout.include?("clean0"))
  end

  #-----------------------------------------------------------------------------
  # Test command misc
  #-----------------------------------------------------------------------------
  def test_update_option
    ARGV.clear and ARGV << 'clean' << '3'
    cmdr = Commander.new(app:'test', version:'0.0.1')
    cmdr.add('clean', 'Clean components', nodes:[
      Option.new(nil, 'Clean given components', allowed:{1 => nil, 3 => nil}, type:Integer)
    ])
    out = Sys.capture{ cmdr.parse! }.stdout.split("\n").map{|x| x.strip_color}
    assert(out.size == 2 && out.include?("test_v0.0.1"))
    assert_equal(3, cmdr[:clean][:clean0])
    cmdr[:clean][:clean0] = 2
    assert_equal(2, cmdr[:clean][:clean0])
  end

  def test_command_name_invalid
    cmdr = Commander.new
    capture = Sys.capture{ assert_raises(SystemExit){ cmdr.add('clean_er', nil)}}
    assert(capture.stdout.include?("Error: command names must be pure lowercase letters or hypen"))
    capture = Sys.capture{ assert_raises(SystemExit){ cmdr.add('CLEAN', nil)}}
    assert(capture.stdout.include?("Error: command names must be pure lowercase letters or hypen"))
    capture = Sys.capture{ assert_raises(SystemExit){ cmdr.add('clean1', nil)}}
    assert(capture.stdout.include?("Error: command names must be pure lowercase letters or hypen"))
  end

  #-----------------------------------------------------------------------------
  # Test Help
  #-----------------------------------------------------------------------------
  def test_sub_command_help_with_examples
    expected =<<EOF
Create a new K8s cluster
Examples:
create foo1 dev foo@example.com

Usage: ./test_commander.rb parent create [options]
    create0                                 Name of the cluster to create: String, Required
    create1                                 Type of cluster to create: String, Required
    create2                                 Email address of owner: String, Required
    -h|--help                               Print command/options help: Flag(false)
EOF
    cmdr = Commander.new
    cmdr.add('parent', 'Something to contain sub', nodes:[
      Command.new('create', 'Create a new K8s cluster', nodes:[
        Option.new(nil, 'Name of the cluster to create', required:true),
        Option.new(nil, 'Type of cluster to create', required:true),
        Option.new(nil, 'Email address of owner', required:true),
      ], examples: "create foo1 dev foo@example.com")
    ])

    ARGV.clear and ARGV << 'parent' << 'create' << '-h'
    capture = Sys.capture{ assert_raises(SystemExit){ cmdr.parse!}}
    assert_equal(expected, capture.stdout.strip_color)
  end

  def test_command_help_with_examples
    expected =<<EOF
Create a new K8s cluster
Examples:
create foo1 dev foo@example.com

Usage: ./test_commander.rb create [options]
    create0                                 Name of the cluster to create: String, Required
    create1                                 Type of cluster to create: String, Required
    create2                                 Email address of owner: String, Required
    -h|--help                               Print command/options help: Flag(false)
EOF
    cmdr = Commander.new
    cmdr.add('create', 'Create a new K8s cluster', nodes:[
      Option.new(nil, 'Name of the cluster to create', required:true),
      Option.new(nil, 'Type of cluster to create', required:true),
      Option.new(nil, 'Email address of owner', required:true),
    ], examples: "create foo1 dev foo@example.com")

    ARGV.clear and ARGV << 'create' << '-h'
    capture = Sys.capture{ assert_raises(SystemExit){ cmdr.parse!}}
    assert_equal(expected, capture.stdout.strip_color)
  end

  def test_sub_command_help_with_more_sub_commands
    sub1_expected =<<EOF
Enable foo component

Usage: ./test_commander.rb enable foo [commands] [options]
COMMANDS:
    bar                                     Enable foo sub component
OPTIONS:
    -h|--help                               Print command/options help: Flag(false)

see './test_commander.rb foo COMMAND --help' for specific command help
EOF
    sub2_expected =<<EOF
Enable foo sub component

Usage: ./test_commander.rb enable foo bar [options]
    -h|--help                               Print command/options help: Flag(false)
EOF
    cmdr = Commander.new
    cmdr.add('enable', "Enable components", nodes:[
      Command.new('foo', 'Enable foo component', nodes:[
        Command.new('bar', 'Enable foo sub component')
      ])
    ])

    # Test manually
    cmd = cmdr.config.find{|x| x.name == "enable"}
    sub1 = cmd.nodes.find{|x| x.class == Command && x.name == 'foo'}
    assert_equal(sub1_expected, sub1.help)
    sub2 = sub1.nodes.find{|x| x.class == Command && x.name == 'bar'}
    assert_equal(sub2_expected, sub2.help)

    # Test using short hand form
    ARGV.clear and ARGV << 'enable' << 'foo' << '-h'
    capture = Sys.capture{ assert_raises(SystemExit){ cmdr.parse! } }
    assert_equal(sub1_expected, capture.stdout)

    ARGV.clear and ARGV << 'enable' << 'foo' << 'bar' << '-h'
    capture = Sys.capture{ assert_raises(SystemExit){ cmdr.parse! } }
    assert_equal(sub2_expected, capture.stdout)
  end

  def test_sub_command_help
    expected =<<EOF
Enable foo component

Usage: ./test_commander.rb enable foo [options]
    -h|--help                               Print command/options help: Flag(false)
EOF
    cmdr = Commander.new
    cmdr.add('enable', "Enable components", nodes:[
      Command.new('foo', 'Enable foo component')
    ])

    # Test manually
    cmd = cmdr.config.find{|x| x.name == "enable"}
    assert_equal(expected, cmd.nodes.find{|x| x.class == Command && x.name == 'foo'}.help)

    # Test using short hand form
    ARGV.clear and ARGV << 'enable' << 'foo' << '-h'
    capture = Sys.capture{ assert_raises(SystemExit){ cmdr.parse! } }
    assert_equal(expected, capture.stdout)
  end

  def test_command_help_with_sub_commands
    expected =<<EOF
Enable components

Usage: ./test_commander.rb enable [commands] [options]
COMMANDS:
    foo                                     Enable foo component
OPTIONS:
    -h|--help                               Print command/options help: Flag(false)

see './test_commander.rb enable COMMAND --help' for specific command help
EOF
    cmdr = Commander.new
    cmdr.add('enable', "Enable components", nodes:[
      Command.new('foo', 'Enable foo component')
    ])

    # Test manually
    assert_equal(expected, cmdr.config.find{|x| x.name == "enable"}.help)

    # Test using short hand form
    ARGV.clear and ARGV << 'enable' << '-h'
    capture = Sys.capture{ assert_raises(SystemExit){ cmdr.parse! } }
    assert_equal(expected, capture.stdout)
  end

  def test_help_with_required_positional
    expected =<<EOF
Build components

Usage: ./test_commander.rb build [options]
    build0                                  Component to build: String, Required
    -h|--help                               Print command/options help: Flag(false)
EOF

    ARGV.clear and ARGV << 'build' << '-h'
    cmdr = Commander.new
    cmdr.add('build', 'Build components', nodes:[
      Option.new(nil, 'Component to build', required:true)
    ])
    capture = Sys.capture{ assert_raises(SystemExit){ cmdr.parse! } }
    assert_equal(expected, capture.stdout)
  end

  def test_command_help
    expected =<<EOF
Clean components

Usage: ./test_commander.rb clean [options]
    clean0                                  Clean given components: Array(String)
                                              all: Clean all components
                                              boot: Clean the boot
                                              image: Clean the image
                                              iso: Clean iso component
    -d|--debug                              Debug mode: Flag(false)
    -h|--help                               Print command/options help: Flag(false)
    -m|--min=MINIMUM                        Set the minimum clean: Integer
                                              1: 1 is the loneliest number
                                              2: 2 is twice as bad as one
                                              3: 3 is thrice as bas as one
    -s|--skip=COMPONENTS                    Skip the given components: Array(String)
                                              image: Skip the image
                                              iso: Skip the iso component
EOF
    cmdr = Commander.new
    cmdr.add('clean', 'Clean components', nodes:[
      Option.new(nil, 'Clean given components', allowed:{
        all: 'Clean all components',
        iso: 'Clean iso component',
        image: 'Clean the image',
        boot: 'Clean the boot'
      }, type:Array),
      Option.new('-d|--debug', 'Debug mode'),
      Option.new('-m|--min=MINIMUM', 'Set the minimum clean', allowed:{
        1 => '1 is the loneliest number',
        2 => '2 is twice as bad as one',
        3 => '3 is thrice as bas as one'
      }, type:Integer),
      Option.new('-s|--skip=COMPONENTS', 'Skip the given components', allowed:{
        iso: 'Skip the iso component',
        image: 'Skip the image'
      }, type:Array)
    ])

    # Test manually
    assert_equal(expected, cmdr.config.find{|x| x.name == "clean"}.help)

    # Test using short hand form
    ARGV.clear and ARGV << 'clean' << '-h'
    capture = Sys.capture{ assert_raises(SystemExit){ cmdr.parse! } }
    assert_equal(expected, capture.stdout)

    # Test using long hand form
    ARGV.clear and ARGV << 'clean' << '--help'
    capture = Sys.capture{ assert_raises(SystemExit){ cmdr.parse! } }
    assert_equal(expected, capture.stdout)
  end

  def test_help_with_default_true
    expected =<<EOF
List command

Usage: ./test_commander.rb list [options]
    --foo-false                             Foo false test: Flag(false)
    --foo-true                              Foo true test: Flag(true)
    -h|--help                               Print command/options help: Flag(false)
EOF
    cmdr = Commander.new
    cmdr.add('list', 'List command', nodes:[
      Option.new('--foo-false', 'Foo false test', type:false),
      Option.new('--foo-true', 'Foo true test', type:true)
    ])

    assert_equal(expected, cmdr.config.find{|x| x.name == "list"}.help)
  end

  def test_help_with_neither_app_nor_version
    expected =<<EOF
Usage: ./test_commander.rb [commands] [options]
Global options:
    -h|--help                               Print command/options help: Flag(false)
COMMANDS:
    list                                    List command

see './test_commander.rb COMMAND --help' for specific command help
EOF
    cmdr = Commander.new
    cmdr.add('list', 'List command')

    # Test raw
    assert_equal(expected, cmdr.help)

    # Test invoked help
    capture = Sys.capture{ assert_raises(SystemExit){ cmdr.parse! } }
    assert_equal(expected, capture.stdout)
  end

  def test_help_with_only_app_version
    expected =<<EOF
Usage: ./test_commander.rb [commands] [options]
Global options:
    -h|--help                               Print command/options help: Flag(false)
COMMANDS:
    list                                    List command

see './test_commander.rb COMMAND --help' for specific command help
EOF
    cmdr = Commander.new(version:'0.0.1')
    cmdr.add('list', 'List command')

    # Test raw
    assert_equal(expected, cmdr.help)

    # Test invoked help
    capture = Sys.capture{ assert_raises(SystemExit){ cmdr.parse! } }
    assert_equal(expected, capture.stdout)
  end

  def test_help_with_only_app_name
    expected =<<EOF
Usage: ./test [commands] [options]
Global options:
    -h|--help                               Print command/options help: Flag(false)
COMMANDS:
    list                                    List command

see './test COMMAND --help' for specific command help
EOF
    cmdr = Commander.new(app:'test')
    cmdr.add('list', 'List command')

    # Test raw
    expected = "#{cmdr.banner}\n#{expected}"
    assert_equal(expected, cmdr.help)

    # Test invoked help
    capture = Sys.capture{ assert_raises(SystemExit){ cmdr.parse! } }
    assert_equal(expected, capture.stdout)
  end

  def test_help_without_examples
    expected =<<EOF
Usage: ./test [commands] [options]
Global options:
    -h|--help                               Print command/options help: Flag(false)
COMMANDS:
    list                                    List command

see './test COMMAND --help' for specific command help
EOF
    cmdr = Commander.new(app:'test', version:'0.0.1')
    cmdr.add('list', 'List command')

    # Test raw
    expected = "#{cmdr.banner}\n#{expected}"
    assert_equal(expected, cmdr.help)

    # Test invoked help
    capture = Sys.capture{ assert_raises(SystemExit){ cmdr.parse! } }
    assert_equal(expected, capture.stdout)
  end

  def test_help_with_examples
    expected =<<EOF
Examples:
List: ./test list

Usage: ./test [commands] [options]
Global options:
    -h|--help                               Print command/options help: Flag(false)
COMMANDS:
    list                                    List command

see './test COMMAND --help' for specific command help
EOF
    cmdr = Commander.new(app:'test', version:'0.0.1', examples:"List: ./test list")
    cmdr.add('list', 'List command')

    # Test raw help
    expected = "#{cmdr.banner}\n#{expected}"
    assert_equal(expected, cmdr.help)

    # Test invoked help
    capture = Sys.capture{ assert_raises(SystemExit){ cmdr.parse! } }
    assert_equal(expected, capture.stdout)
  end

  def test_help_is_reserved_option_even_in_sub_commands
    cmdr = Commander.new
    capture = Sys.capture{ assert_raises(SystemExit){
      cmdr.add('test', '', nodes:[
        Command.new('foo', '', nodes:[
          Command.new('bar', '', nodes:[
            Option.new('-h|--help', 'help is reserved')
          ])
        ])
      ])
    }}
    assert_equal("Error: 'help' is a reserved option name!\n", capture.stdout.strip_color)
  end

  def test_help_is_reserved_option
    cmdr = Commander.new
    capture = Sys.capture{ assert_raises(SystemExit){
      cmdr.add('test', 'help is reserved', nodes:[
        Option.new('-h|--help', 'help is reserved')
      ])
    }}
    assert_equal("Error: 'help' is a reserved option name!\n", capture.stdout.strip_color)
  end

  #-----------------------------------------------------------------------------
  # Test the Option Class
  #-----------------------------------------------------------------------------
  def test_option_required

    # All options are optional by default
    assert(!Option.new(nil, nil).required)
    assert(!Option.new("-h|--help", nil).required)

    # All options may be required
    assert(Option.new(nil, nil, required:true).required)
    assert(Option.new("-h|--help", nil, required:true).required)
  end

  def test_option_allowed

    # Test allowed for positional options
    assert_empty(Option.new(nil, nil).allowed)
    assert_equal({foo: 'Foo desc', bar: 'Bar desc'},
      Option.new(nil, nil, allowed:{foo: 'Foo desc', bar: 'Bar desc'}).allowed)

    # Test allowed for named options
    assert_empty(Option.new('--build=COMPONENT', nil, type:String).allowed)
    assert_equal({foo: nil, bar: nil},
      Option.new('--build=COMPONENT', nil, type:String, allowed:{foo: nil, bar: nil}).allowed)

    # Test mixed types in allow should fail
    capture = Sys.capture{ assert_raises(SystemExit){
      Option.new(nil, nil, allowed:{1 => nil, foo: nil})
    }}
    assert_equal("Error: mixed allowed types!\n", capture.stdout.strip_color)
  end

  # Allowed types are (Bool, Integer, String, Array)
  def test_option_type

    # Test defaults for both option types
    #----------------------------------------------------
    # Positional option with no type defaults to String
    assert_equal(String, Option.new(nil, nil).type)
    # Named option with no type defaults to FalseClass
    assert_equal(FalseClass, Option.new("--help", nil).type)

    # Test valid specified types
    #----------------------------------------------------
    assert_equal(FalseClass, Option.new('--help', nil, type:FalseClass).type)
    assert_equal(FalseClass, Option.new('--help', nil, type:false).type)
    assert_equal(TrueClass, Option.new('--help', nil, type:TrueClass).type)
    assert_equal(TrueClass, Option.new('--help', nil, type:true).type)
    assert_equal(String, Option.new(nil, nil, type:String).type)
    assert_equal(Integer, Option.new(nil, nil, type:Integer).type)
    assert_equal(Array, Option.new(nil, nil, type:Array).type)

    # Invalid type
    $stdout.stub(:write, nil){
      assert_raises(SystemExit){Option.new(nil, nil, type:Hash)}
    }

    # Type not set for named option that is expecting an incoming value
    capture = Sys.capture{ assert_raises(SystemExit){ Option.new("-f|--file=HINT", "desc")}}
    assert_equal("Error: option type must be set!\n", capture.stdout.strip_color)
  end

  # Option description is free form text and has no checks
  def test_option_desc
    assert_equal("foobar", Option.new(nil, "foobar").desc)
  end

  # Testing the key for named options
  # i.e. has a valid long hand key been given with optionally a HINT or short hand form
  def test_option_key_composed_of_short_long_hint

    # Mal-formed named options
    #---------------------------------------------------------------------------
    $stdout.stub(:write, nil){

      # No long hand given, long hand is required
      assert_raises(SystemExit){Option.new("-s", nil)}
      assert_raises(SystemExit){Option.new("-s=COMPONENTS", nil)}

      # HINT can not include equal symbol
      assert_raises(SystemExit){Option.new("--skip=FOO=BAR", nil)}
      assert_raises(SystemExit){Option.new("-s|--skip=FOO=BAR", nil)}

      # Long hand form is invalid
      assert_raises(SystemExit){Option.new("--skip|", nil)}
      assert_raises(SystemExit){Option.new("-s|skip", nil)}
      assert_raises(SystemExit){Option.new("-s|=HINT", nil)}
      assert_raises(SystemExit){Option.new("-s|--skip|", nil)}

      # Short hand form is invalid
      assert_raises(SystemExit){Option.new("--skip|-s", nil)}
      assert_raises(SystemExit){Option.new("-s, --skip=FOO", nil)}
    }

    # Well-formed named options
    #---------------------------------------------------------------------------
    # long hand only, simple name, flag
    opt = Option.new("--skip", nil)
    assert_nil(opt.hint)
    assert_equal("--skip", opt.key)
    assert_equal("--skip", opt.long)
    assert_nil(opt.short)

    # long hand only with dash in name, flag
    opt = Option.new("--skip-foo", nil)
    assert_nil(opt.hint)
    assert_equal("--skip-foo", opt.key)
    assert_equal("--skip-foo", opt.long)
    assert_nil(opt.short)

    # long hand only with incoming String value
    opt = Option.new("--skip=HINT", nil, type:String)
    assert_equal("HINT", opt.hint)
    assert_equal("--skip", opt.long)
    assert_nil(opt.short)

    # short/long hand simple name, flag
    opt = Option.new("-s|--skip", nil)
    assert_nil(opt.hint)
    assert_equal("-s|--skip", opt.key)
    assert_equal("-s", opt.short)
    assert_equal("--skip", opt.long)

    # short/long hand with incoming String value
    opt = Option.new("-s|--skip=HINT", nil, type:String)
    assert_equal("HINT", opt.hint)
    assert_equal("-s|--skip=HINT", opt.key)
    assert_equal("-s", opt.short)
    assert_equal("--skip", opt.long)
  end
end

# vim: ft=ruby:ts=2:sw=2:sts=2
