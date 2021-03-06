require 'spec_helper'
require 'celluloid/test'
# Celluloid.logger.level = ::Logger::Severity::INFO
require_relative 'test_pty'

shared_examples 'track sensors' do
  # device_glob includes some bad files in the glob.
  # TrackSensors should read from any/all serial device files matched and ignore others
  subject(:track_sensor) { described_class.new device_glob: "{#{@device.path},#{@second_device.path},/tmp/nonexistent,/etc/profile}" }

  let(:device_data) { '' }

  before :each do
    @device        = TestPTY.new
    @second_device = TestPTY.new
    @device.pty.write device_data
  end

  around :each do |example|
    Celluloid.boot
    Celluloid.start
    example.call
    Celluloid.shutdown
  end

  after :each do
    @device.close
    @second_device.close
  end

  describe '#run' do
    context 'with results queued' do
      let(:device_data) { device_initialization_data + result_data }

      it 'publishes the race results on the "race results" channel' do
        expect(Subscriber.for_race_results).to receive(:message).with 'race results', [
          {time: 3.1, track: 1},
          {time: 3.2, track: 2},
          {time: 3.3, track: 3},
          {time: 3.4, track: 4},
        ]
        track_sensor.async.run
        sleep 0.1
      end
    end

    context 'when there are no results' do
      it 'does not publish anything' do
        expect(Subscriber.for_race_results).not_to receive(:message)
        track_sensor.async.run
        sleep 0.1
      end
    end
  end

  describe '#new_race' do
    it 'writes the new race sequence to the device, if any' do
      unless new_race_command.nil?
        track_sensor.new_race
        sleep 0.1
        expect(@device.pty.read_nonblock(new_race_command.length)).to eq new_race_command
      end
    end
  end

  describe '#close' do
    it 'closes all open devices' do
      # There are no external effects, so ...
      expect{track_sensor.close}.not_to raise_exception
    end
  end

  describe '.random_result_example' do
    it 'returns an example string that matches the times_regex' do
      expect(described_class.random_result_example).to match track_sensor.times_regex
    end
  end

  describe 'hot changing devices' do
    let(:device_data) { result_data }

    it 'attempts to read from any/all of the files specified in the :device_glob option' do
      expect(Subscriber.for_race_results).to receive(:message).twice
      @second_device.pty.write device_data.sub('3', '2')
      track_sensor.async.run
      sleep 0.1
    end
  end
end

class Subscriber
  include Celluloid
  include Celluloid::Notifications

  def self.for_race_results
    new('race results').wrapped_object
  end

  def initialize(topic)
    subscribe(topic, :message)
  end

  def message(topic, arg)
  end
end
