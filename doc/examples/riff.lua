local serial = require 'serial'

local read = serial.read
local write = serial.write
local serialize = serial.serialize
local struct = serial.struct
local fstruct = serial.fstruct
local alias = serial.alias

-- WAVE from http://www.sonicspot.com/guide/wavefiles.html
-- AVI from http://yaai.sourceforge.net/yaai/fileformat.html
-- AVI from http://www.alexander-noe.com/video/documentation/avi.pdf

------------------------------------------------------------------------------

function read.fourcc(stream)
	local bytes,err = read.bytes(stream, 4)
	if not bytes then return nil,err end
	return bytes:gsub(' *$', '')
end
function serialize.fourcc(value)
	return value..string.rep(' ', 4-#value)
end

alias.riff_file = {'array', '*', 'riff_chunk'}

function fstruct.riff_chunk_raw(self)
	self 'type' ('fourcc')
	self 'data' ('sizedbuffer', 'uint32', 'le')
	if (#self.data % 2) ~= 0 then
		self 'pad_byte' ('uint8')
	end
end

function read.riff_chunk(stream)
	local chunk = read.riff_chunk_raw(stream)
	local read = read['riff_'..chunk.type..'_chunk']
	if read then
		local substream = serial.buffer(chunk.data)
		local data,err = read(substream)
		if not data then return nil,err end
		chunk.data = data
		local __trailing_bytes = serial.read.bytes(substream, '*')
		if __trailing_bytes~="" then
			chunk.__trailing_bytes = __trailing_bytes
		end
	end
	return chunk
end

function serialize.riff_chunk(value)
	local chunk = {}
	for k,v in pairs(value) do chunk[k] = v end
	local read = read['riff_'..chunk.type..'_chunk']
	if read then
		local data,err = read(serial.buffer(chunk.data))
		if not data then return nil,err end
		chunk.data = data
		if chunk.__trailing_bytes then
			chunk.data = chunk.data..chunk.__trailing_bytes
		end
	end
	return serialize.riff_chunk_raw(chunk)
end

struct.riff_RIFF_chunk = {
	{'form_type', 'fourcc'},
	{'chunks', 'array', '*', 'riff_chunk'},
}

struct.riff_LIST_chunk = {
	{'list_type', 'fourcc'},
	{'chunks', 'array', '*', 'riff_chunk'},
}

alias.riff_AVI_chunk = {'array', '*', 'riff_chunk'}

local riff_fmt_audio_format = serial.util.enum{
	-- taken from http://www.iana.org/assignments/wave-avi-codec-registry
	UNKNOWN					= 0x0000,	-- Microsoft Unknown Wave Format
	PCM						= 0x0001,	-- Microsoft PCM Format
	ADPCM					= 0x0002,	-- Microsoft ADPCM Format
	IEEE_FLOAT				= 0x0003,	-- IEEE Float
	VSELP					= 0x0004,	-- Compaq Computer's VSELP
	IBM_CVSD				= 0x0005,	-- IBM CVSD
	ALAW					= 0x0006,	-- Microsoft ALAW
	MULAW					= 0x0007,	-- Microsoft MULAW
	OKI_ADPCM				= 0x0010,	-- OKI ADPCM
	DVI_ADPCM				= 0x0011,	-- Intel's DVI ADPCM
	MEDIASPACE_ADPCM		= 0x0012,	-- Videologic's MediaSpace ADPCM
	SIERRA_ADPCM			= 0x0013,	-- Sierra ADPCM
	G723_ADPCM				= 0x0014,	-- G.723 ADPCM
	DIGISTD					= 0x0015,	-- DSP Solution's DIGISTD
	DIGIFIX					= 0x0016,	-- DSP Solution's DIGIFIX
	DIALOGIC_OKI_ADPCM		= 0x0017,	-- Dialogic OKI ADPCM
	MEDIAVISION_ADPCM		= 0x0018,	-- MediaVision ADPCM
	CU_CODEC				= 0x0019,	-- HP CU
	YAMAHA_ADPCM			= 0x0020,	-- Yamaha ADPCM
	SONARC					= 0x0021,	-- Speech Compression's Sonarc
	DSPGROUP_TRUESPEECH		= 0x0022,	-- DSP Group's True Speech
	ECHOSC1					= 0x0023,	-- Echo Speech's EchoSC1
	AUDIOFILE_AF36			= 0x0024,	-- Audiofile AF36
	APTX					= 0x0025,	-- APTX
	AUDIOFILE_AF10			= 0x0026,	-- AudioFile AF10
	PROSODY_1612			= 0x0027,	-- Prosody 1612
	LRC						= 0x0028,	-- LRC
	DOLBY_AC2				= 0x0030,	-- Dolby AC2
	GSM610					= 0x0031,	-- GSM610
	MSNAUDIO				= 0x0032,	-- MSNAudio
	ANTEX_ADPCME			= 0x0033,	-- Antex ADPCME
	CONTROL_RES_VQLPC		= 0x0034,	-- Control Res VQLPC
	DIGIREAL				= 0x0035,	-- Digireal
	DIGIADPCM				= 0x0036,	-- DigiADPCM
	CONTROL_RES_CR10		= 0x0037,	-- Control Res CR10
	NMS_VBXADPCM			= 0x0038,	-- NMS VBXADPCM
	ROLAND_RDAC				= 0x0039,	-- Roland RDAC
	ECHOSC3					= 0x003A,	-- EchoSC3
	ROCKWELL_ADPCM			= 0x003B,	-- Rockwell ADPCM
	ROCKWELL_DIGITALK		= 0x003C,	-- Rockwell Digit LK
	XEBEC					= 0x003D,	-- Xebec
	G721_ADPCM				= 0x0040,	-- Antex Electronics G.721
	G728_CELP				= 0x0041,	-- G.728 CELP
	MSG723					= 0x0042,	-- MSG723
	MPEG					= 0x0050,	-- MPEG
	RT24					= 0x0052,	-- RT24
	PAC						= 0x0053,	-- PAC
	MPEGLAYER3				= 0x0055,	-- MPEG Layer 3
	LUCENT_G723				= 0x0059,	-- Lucent G.723
	CIRRUS					= 0x0060,	-- Cirrus
	ESPCM					= 0x0061,	-- ESPCM
	VOXWARE					= 0x0062,	-- Voxware
	CANOPUS_ATRAC			= 0x0063,	-- Canopus Atrac
	G726_ADPCM				= 0x0064,	-- G.726 ADPCM
	G722_ADPCM				= 0x0065,	-- G.722 ADPCM
	DSAT					= 0x0066,	-- DSAT
	DSAT_DISPLAY			= 0x0067,	-- DSAT Display
	VOXWARE_BYTE_ALIGNED	= 0x0069,	-- Voxware Byte Aligned
	VOXWARE_AC8				= 0x0070,	-- Voxware AC8
	VOXWARE_AC10			= 0x0071,	-- Voxware AC10
	VOXWARE_AC16			= 0x0072,	-- Voxware AC16
	VOXWARE_AC20			= 0x0073,	-- Voxware AC20
	VOXWARE_RT24			= 0x0074,	-- Voxware MetaVoice
	VOXWARE_RT29			= 0x0075,	-- Voxware MetaSound
	VOXWARE_RT29HW			= 0x0076,	-- Voxware RT29HW
	VOXWARE_VR12			= 0x0077,	-- Voxware VR12
	VOXWARE_VR18			= 0x0078,	-- Voxware VR18
	VOXWARE_TQ40			= 0x0079,	-- Voxware TQ40
	SOFTSOUND				= 0x0080,	-- Softsound
	VOXWARE_TQ60			= 0x0081,	-- Voxware TQ60
	MSRT24					= 0x0082,	-- MSRT24
	G729A					= 0x0083,	-- G.729A
	MVI_MV12				= 0x0084,	-- MVI MV12
	DF_G726					= 0x0085,	-- DF G.726
	DF_GSM610				= 0x0086,	-- DF GSM610
	ISIAUDIO				= 0x0088,	-- ISIAudio
	ONLIVE					= 0x0089,	-- Onlive
	SBC24					= 0x0091,	-- SBC24
	DOLBY_AC3_SPDIF			= 0x0092,	-- Dolby AC3 SPDIF
	ZYXEL_ADPCM				= 0x0097,	-- ZyXEL ADPCM
	PHILIPS_LPCBB			= 0x0098,	-- Philips LPCBB
	PACKED					= 0x0099,	-- Packed
	RHETOREX_ADPCM			= 0x0100,	-- Rhetorex ADPCM
	IRAT					= 0x0101,	-- BeCubed Software's IRAT
	VIVO_G723				= 0x0111,	-- Vivo G.723
	VIVO_SIREN				= 0x0112,	-- Vivo Siren
	DIGITAL_G723			= 0x0123,	-- Digital G.723
	CREATIVE_ADPCM			= 0x0200,	-- Creative ADPCM
	CREATIVE_FASTSPEECH8	= 0x0202,	-- Creative FastSpeech8
	CREATIVE_FASTSPEECH10	= 0x0203,	-- Creative FastSpeech10
	QUARTERDECK				= 0x0220,	-- Quarterdeck
	FM_TOWNS_SND			= 0x0300,	-- FM Towns Snd
	BTV_DIGITAL				= 0x0400,	-- BTV Digital
	VME_VMPCM				= 0x0680,	-- VME VMPCM
	OLIGSM					= 0x1000,	-- OLIGSM
	OLIADPCM				= 0x1001,	-- OLIADPCM
	OLICELP					= 0x1002,	-- OLICELP
	OLISBC					= 0x1003,	-- OLISBC
	OLIOPR					= 0x1004,	-- OLIOPR
	LH_CODEC				= 0x1100,	-- LH Codec
	NORRIS					= 0x1400,	-- Norris
	ISIAUDIO				= 0x1401,	-- ISIAudio
	SOUNDSPACE_MUSICOMPRESS	= 0x1500,	-- Soundspace Music Compression
	DVM						= 0x2000,	-- AC3 DVM
}

struct.riff_fmt_chunk = {
	{'audio_format',	'enum', riff_fmt_audio_format, 'uint16', 'le'},
	{'num_channels',	'uint16', 'le'},
	{'sample_rate',		'uint32', 'le'},
	{'byte_rate',		'uint32', 'le'},
	{'block_align',		'uint16', 'le'},
	{'bits_per_sample',	'uint16', 'le'},
}

-- riff_data_chunk -- format specific

-- riff_fact_chunk -- format specific

alias.riff_wavl_chunk = {'array', '*', 'riff_chunk'}

struct.riff_slnt_chunk = {
	{'silence_sample', 'uint32', 'le'},
}

struct.riff_cue_chunk = {
	{'cue_points', 'sizedarray', {'uint32', 'le'}, 'riff_cue_point'},
}

struct.cue_point = {
	{'id',				'uint32', 'le'},
	{'position',		'uint32', 'le'},
	{'data_chunk_id',	'uint32', 'le'},
	{'chunk_start',		'uint32', 'le'},
	{'block_start',		'uint32', 'le'},
	{'sample_offset',	'uint32', 'le'},
}

struct.riff_plst_chunk = {
	{'segments', 'sizedarray', {'uint32', 'le'}, 'riff_plst_segment'},
}

struct.riff_plst_segment = {
	{'cue_point_id',	'uint32', 'le'},
	{'length',			'uint32', 'le'}, -- in samples
	{'num_repeat',		'uint32', 'le'},
}

struct.riff_list_chunk = {
	{'list_type', 'fourcc'},
	{'chunks', 'array', '*', 'riff_chunk'},
}

struct.riff_labl_chunk = {
	{'cue_point_id',	'uint32', 'le'},
	{'text',			'cstring'},
}

struct.riff_ltxt_chunk = {
	{'cue_point_id',	'uint32', 'le'},
	{'sample_length',	'uint32', 'le'},
	{'purpose',			'fourcc'},
	{'country',			'uint16', 'le'},
	{'language',		'uint16', 'le'},
	{'dialect',			'uint16', 'le'},
	{'code_page',		'uint16', 'le'},
	{'text',			'cstring'},
}

struct.riff_note_chunk = struct.riff_labl_chunk

local smpte_format = serial.util.enum{
	["no SMPTE offset"] = 0,
	["24 frames per second"] = 24,
	["25 frames per second"] = 25,
	["30 frames per second with frame dropping (30 drop)"] = 29,
	["30 frames per second"] = 30,
}

function fstruct.riff_smpl_chunk(self)
	self 'manufacturer' ('uint32', 'le')
	self 'product' ('uint32', 'le')
	self 'sample_period' ('uint32', 'le')
	self 'midi_unity_note' ('uint32', 'le')
	self 'midi_pitch_fraction' ('uint32', 'le')
	self 'smpte_format' ('enum', smpte_format, 'uint32', 'le')
	self 'smpte_offset' ('uint32', 'le')
	self 'num_sample_loops' ('uint32', 'le')
	self 'sampler_data_size' ('uint32', 'le')
	self 'sample_loops' ('array', self.num_sample_loops, 'sample_loop')
	self 'sampler_data' ('bytes', sampler_data_size)
end

local sample_loop_type = {
	loop_forward = 0,		-- Loop forward (normal)
	alternating_loop = 1,	-- Alternating loop (forward/backward, also known as Ping Pong)
	loop_backward = 2,		-- Loop backward (reverse)
--	3 - 31					-- Reserved for future standard types
--	32 - 0xFFFFFFFF			-- Sampler specific types (defined by manufacturer)
}

struct.sample_loop = {
	{'cue_point_id',	'uint32', 'le'},
	{'type',			'uint32', 'le'},
	{'start',			'uint32', 'le'},
	{'end',				'uint32', 'le'},
	{'fraction',		'uint32', 'le'},
	{'play_count',		'uint32', 'le'},
}

struct.riff_inst_chunk = {
	{'unshifted_note',	'uint8'}, -- 0 - 127
	{'fine_tune',		'sint8'}, -- -50 dB - +50 dB
	{'gain',			'sint8'}, -- -64 - +64
	{'low_note',		'uint8'}, -- 0 - 127
	{'high_note',		'uint8'}, -- 0 - 127
	{'low_velocity',	'uint8'}, -- 1 - 127
	{'high_velocity',	'uint8'}, -- 1 - 127
}

struct.riff_avih_chunk = {
	{'microseconds_per_frame',	'uint32', 'le'},
	{'max_bytes_per_second',	'uint32', 'le'},
	{'padding_granularity',		'uint32', 'le'},
	{'flags',					'uint32', 'le'},
	{'total_frames',			'uint32', 'le'},
	{'initial_frames',			'uint32', 'le'},
	{'streams',					'uint32', 'le'},
	{'suggested_buffer_size',	'uint32', 'le'},
	{'width',					'uint32', 'le'},
	{'height',					'uint32', 'le'},
	{'reserved',				'array', 4, 'uint32', 'le'},
}

local stream_type = serial.util.enum{
	video = 'vids',
	audio = 'auds',
	subtitle = 'txts',
}

local stream_flags = {
	DISABLED			= 0x00000001,
	VIDEO_PALCHANGES	= 0x00010000,
}

struct.RECT = {
	{'left', 'uint32', 'le'},
	{'top', 'uint32', 'le'},
	{'right', 'uint32', 'le'},
	{'bottom', 'uint32', 'le'},
}

struct.riff_strh_chunk = {
	{'type',					'enum', stream_type, 'fourcc'},
	{'handler',					'fourcc'}, -- FourCC of the codec
	{'flags',					'flags', stream_flags, 'uint32', 'le'},
	{'priority',				'uint16', 'le'},
	{'language',				'uint16', 'le'},
	{'initial_frames',			'uint32', 'le'},
	{'scale',					'uint32', 'le'},
	{'rate',					'uint32', 'le'},
	{'start',					'uint32', 'le'},
	{'length',					'uint32', 'le'},
	{'suggested_buffer_size',	'uint32', 'le'},
	{'quality',					'uint32', 'le'},
	{'sample_size',				'uint32', 'le'},
	{'reserved',				'array', 2, 'uint32', 'le'},
}

-- riff_strf_chunk -- stream type specific

struct.index_entry = {
	{'id',				'fourcc'},
	{'flags',			'uint32', 'le'},
	{'chunk_offset',	'uint32', 'le'},
	{'chunk_length',	'uint32', 'le'},
}

alias.riff_idx1_chunk = {'array', '*', 'index_entry'}

struct.riff_dmlh_chunk = {
	{'total_frames', 'uint32', 'le'},
}

