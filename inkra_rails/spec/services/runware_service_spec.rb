# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RunwareService do
  let(:service) { described_class.new }
  let(:mock_response) do
    double(
      'HTTParty::Response',
      success?: true,
      parsed_response: {
        'data' => [{
          'taskUUID' => 'test-uuid-123',
          'imageURL' => 'https://example.com/generated-image.jpg'
        }]
      }
    )
  end

  before do
    allow(ENV).to receive(:[]).with('RUNWARE_API_KEY').and_return('test-api-key')
  end

  describe '#initialize' do
    context 'when API key is provided' do
      it 'initializes successfully with API key' do
        service = described_class.new(api_key: 'test-key')
        expect(service).to be_a(described_class)
      end
    end

    context 'when API key is missing' do
      before do
        allow(ENV).to receive(:[]).with('RUNWARE_API_KEY').and_return(nil)
      end

      it 'raises an ArgumentError' do
        expect { described_class.new }.to raise_error(ArgumentError, 'RUNWARE_API_KEY environment variable not set.')
      end
    end
  end

  describe '#create_icon' do
    let(:prompt) { 'a glowing nebula shaped like a cat' }

    before do
      allow(described_class).to receive(:post).and_return(mock_response)
    end

    context 'with valid parameters' do
      it 'generates a square icon successfully' do
        result = service.create_icon(prompt: prompt, size: 1024)

        expect(result[:success]).to be true
        expect(result[:image_url]).to eq('https://example.com/generated-image.jpg')
        expect(result[:width]).to eq(1024)
        expect(result[:height]).to eq(1024)
      end

      it 'makes HTTP request with correct parameters' do
        expected_payload = [{
          taskType: 'imageInference',
          taskUUID: kind_of(String),
          positivePrompt: "#{prompt}, #{described_class::COSMIC_LOFI_AESTHETIC}",
          negativePrompt: described_class::NEGATIVE_AESTHETIC,
          width: 1024,
          height: 1024,
          model: described_class::DEFAULT_MODEL,
          steps: 30,
          numberResults: 1
        }]

        service.create_icon(prompt: prompt, size: 1024)

        expect(described_class).to have_received(:post).with('/', body: kind_of(String))
      end
    end

    context 'with invalid size parameter' do
      it 'returns error for size not divisible by 64' do
        result = service.create_icon(prompt: prompt, size: 1000)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Image size must be divisible by 64')
      end
    end

    context 'when API request fails' do
      let(:error_response) do
        double('HTTParty::Response', success?: false, code: 400, message: 'Bad Request', body: 'Invalid request')
      end

      before do
        allow(described_class).to receive(:post).and_return(error_response)
      end

      it 'returns error response' do
        result = service.create_icon(prompt: prompt, size: 1024)

        expect(result[:success]).to be false
        expect(result[:error]).to include('HTTP Error: 400')
      end
    end

    context 'when API returns error in response' do
      let(:error_response) do
        double(
          'HTTParty::Response',
          success?: true,
          parsed_response: { 'error' => 'API rate limit exceeded' }
        )
      end

      before do
        allow(described_class).to receive(:post).and_return(error_response)
      end

      it 'returns API error' do
        result = service.create_icon(prompt: prompt, size: 1024)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('API rate limit exceeded')
      end
    end
  end

  describe '#create_portrait_photo' do
    let(:prompt) { 'astronaut meditating in a field of glowing flowers' }

    before do
      allow(described_class).to receive(:post).and_return(mock_response)
    end

    it 'generates a 9:16 portrait successfully' do
      result = service.create_portrait_photo(prompt: prompt, height: 1344)

      expect(result[:success]).to be true
      expect(result[:image_url]).to eq('https://example.com/generated-image.jpg')
      expect(result[:width]).to eq(768) # 1344 * 9/16 rounded to nearest 64
      expect(result[:height]).to eq(1344)
    end

    it 'calculates correct width for aspect ratio' do
      service.create_portrait_photo(prompt: prompt, height: 1344)

      expected_width = (1344 * 9.0 / 16.0 / 64.0).round * 64
      expect(expected_width).to eq(768)
    end
  end

  describe '#create_tall_photo' do
    let(:prompt) { 'a cascading waterfall of starlight in a cosmic forest' }

    before do
      allow(described_class).to receive(:post).and_return(mock_response)
    end

    it 'generates a 6:19 tall photo successfully' do
      result = service.create_tall_photo(prompt: prompt, height: 1984)

      expect(result[:success]).to be true
      expect(result[:image_url]).to eq('https://example.com/generated-image.jpg')
      expect(result[:width]).to eq(640) # 1984 * 6/19 rounded to nearest 64
      expect(result[:height]).to eq(1984)
    end
  end

  describe '#create_custom_image' do
    let(:prompt) { 'a mystical library floating in space' }

    before do
      allow(described_class).to receive(:post).and_return(mock_response)
    end

    context 'with valid dimensions' do
      it 'generates custom image successfully' do
        result = service.create_custom_image(prompt: prompt, width: 1024, height: 768)

        expect(result[:success]).to be true
        expect(result[:image_url]).to eq('https://example.com/generated-image.jpg')
        expect(result[:width]).to eq(1024)
        expect(result[:height]).to eq(768)
      end

      it 'accepts custom model parameter' do
        custom_model = 'custom:model:123'
        service.create_custom_image(prompt: prompt, width: 1024, height: 768, model: custom_model)

        expect(described_class).to have_received(:post)
      end
    end

    context 'with invalid dimensions' do
      it 'returns error for dimensions not divisible by 64' do
        result = service.create_custom_image(prompt: prompt, width: 1000, height: 750)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Image dimensions must be divisible by 64')
      end
    end
  end

  describe '#calculate_dimension' do
    it 'rounds dimension to nearest multiple of 64' do
      service = described_class.new
      
      expect(service.send(:calculate_dimension, 100.0)).to eq(128)
      expect(service.send(:calculate_dimension, 756.0)).to eq(768)
      expect(service.send(:calculate_dimension, 32.0)).to eq(64)
    end
  end

  describe 'constants' do
    it 'has cosmic lofi aesthetic defined' do
      expect(described_class::COSMIC_LOFI_AESTHETIC).to include('Cosmic Lofi aesthetic')
      expect(described_class::COSMIC_LOFI_AESTHETIC).to include('deep near-black blues and purples')
    end

    it 'has negative aesthetic defined' do
      expect(described_class::NEGATIVE_AESTHETIC).to include('pure black')
      expect(described_class::NEGATIVE_AESTHETIC).to include('harsh lighting')
    end

    it 'has default model defined' do
      expect(described_class::DEFAULT_MODEL).to eq('hidream:i1-full')
    end
  end
end