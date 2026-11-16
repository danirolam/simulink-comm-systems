function build_L3T3_p2
%BUILD_L3T3_P2  ECSE 308 L3T3 Part 2: binary ASK, PSK, FSK and 4-QAM.
%
%   build_L3T3_p2      builds four models under models/ and opens the first
%
%   L3T3_ASK    pages 11-12, question 1. bit x carrier: carrier on or off.
%   L3T3_PSK    pages 13-14, question 2. (+-1) x carrier: carrier or its
%               upside-down copy.
%   L3T3_FSK    pages 15-16, question 3. A Switch picks a 2.5 kHz sine for
%               a 1 and a 3.5 kHz sine for a 0.
%   L3T3_4QAM   pages 17-18, question 4. Two bits per symbol, one on cos and
%               one on sin, I cos - Q sin.
%
% Common to all four: 1 bit per ms (Bernoulli, seed 67, 1e-3 s). The carrier
% sines are sample based at 1e-7 s; 5000 samples per period = 2 kHz. Every
% spectrum sits behind a Rate Transition at 0.5e-4 s (20 kHz), so it shows
% -10 to +10 kHz. Receivers multiply by a local copy of the carrier, add up
% one bit's worth in Integrate and Dump, take the Sign, and a lookup table
% turns that back into 0/1.
%
% Settings the handout leaves open:
%
%   * Stop time 0.3 s (300 bits): enough for a smooth spectrum. Solver
%     discrete, fixed step 1e-7 s, so a run is 3 million steps.
%   * Integrate and Dump integration period: one bit. For ASK and PSK the
%     product runs at 1e-7 s, so 1 ms = 10000 samples. In the FSK drawing a
%     Rate Transition (0.5e-4 s) sits before it, so 1 ms = 20 samples.
%   * FSK's first Rate Transition (the "1/z" one, slow bits to the fast
%     Switch) has no setting given; it outputs at 1e-7 s, the sines' rate.
%   * Switch criterion "u2 > Threshold", threshold 0, as its icon shows.
%   * ASK's Spectrum (Product) is drawn with no Rate Transition, so it sees
%     the 10 MHz rate; it is zoomed to -10 to +10 kHz.
%   * Scopes are stacked (one plot per input) and show 10 ms = 10 bits.
%     Scope (4QAM) also shows the I and Q levels (inputs 2 and 3).
%
% Ends each model by reading every parameter back (ok / CHECK), listing which
% library each block came from, and compiling it (Ctrl+D), before it saves.

note('reset');
checkproducts();
outdir = fullfile(pwd, 'models');
if ~exist(outdir, 'dir'), mkdir(outdir); end

buildask(outdir);
buildpsk(outdir);
buildfsk(outdir);
buildqam4(outdir);
open_system('L3T3_ASK');
report();
bconn('print');
end

function bconn(sys, dst)
% The Bernoulli source is added by hand; collect the ports it must feed and
% print them as one list per model at the end.
persistent todo
if isempty(todo), todo = {}; end
if strcmp(sys, 'print')
    fprintf(['\nAdd the Bernoulli Binary Generator yourself in each model below.\n' ...
        'Settings: Probability of zero 0.5, Source of initial seed: Parameter, ' ...
        'Initial seed 67, Sample time 1e-3.\nConnect its output to:\n']);
    last = '';
    for k = 1:size(todo, 1)
        if ~strcmp(todo{k, 1}, last)
            fprintf('  %s\n', todo{k, 1});
            last = todo{k, 1};
        end
        fprintf('      -> %s\n', todo{k, 2});
    end
    fprintf('\n');
    todo = {};
    return
end
todo(end+1, :) = {sys, regexprep(dst, '/1$', ' (input 1)')};
end

function c = consts()
c.TS   = '1e-7';      % carrier sample time
c.TB   = '1e-3';      % one bit
c.RT   = '0.5e-4';    % Rate Transition in front of each spectrum
c.STOP = '0.3';
c.SPAN = 0.01;        % scopes: 10 bits
c.RBW  = 50;
end

% =====================================================================
% Binary ASK (pages 11-12)
% =====================================================================
function buildask(outdir)
c = consts();
expect('reset');
sys = newmodel('L3T3_ASK', outdir, c.STOP, c.TS, 'FixedStepDiscrete');
B = 'Bernoulli Binary Generator (Source)';

addsineS(sys, 'Sine Wave (Mod)', '5000', '0', c.TS, [285 645 338 705]);
addprod(sys, 'Product (Mod)', [405 590 458 650]);
bconn(sys, 'Product (Mod)/1');
conn(sys, 'Sine Wave (Mod)/1', 'Product (Mod)/2');

addscope(sys, 'Scope (Mod)', 2, [540 405 600 470], 'Bits (1) and ASK signal (2)', c.SPAN, true);
bconn(sys, 'Scope (Mod)/1');
conn(sys, 'Product (Mod)/1', 'Scope (Mod)/2');
addrt(sys, 'Rate Transition', c.RT, [518 795 593 863]);
addspec(sys, 'Spectrum (Mod)', [648 773 733 878], specp('Spectrum (Mod): ASK', [], c.RBW, 3, 10));
conn(sys, 'Product (Mod)/1', 'Rate Transition/1');
conn(sys, 'Rate Transition/1', 'Spectrum (Mod)/1');

receiver(sys, 'Product (Mod)', B, '10000', c, [608 645 668 705], [770 605 825 665]);

% ASK draws Scope (Product) as [bits, demod product] and a Spectrum (Product)
% straight off the product.
addscope(sys, 'Scope (Product)', 2, [1028 240 1088 300], 'Bits (1) and ASK x carrier (2)', c.SPAN, true);
bconn(sys, 'Scope (Product)/1');
conn(sys, 'Product (Demod)/1', 'Scope (Product)/2');
addspec(sys, 'Spectrum (Product)', [1013 383 1098 488], ...
    specp('Spectrum (Product): ASK x carrier', [-10000 10000], c.RBW, 0, 0));
conn(sys, 'Product (Demod)/1', 'Spectrum (Product)/1');

set_param(sys, 'Description', 'ECSE 308 L3T3 Part 2: binary ASK (on-off keying), 1 kb/s on a 2 kHz carrier.');
audit();
libraries(sys);
compiles(sys);
savemodel(sys, outdir);
end

% =====================================================================
% Binary PSK (pages 13-14)
% =====================================================================
function buildpsk(outdir)
c = consts();
expect('reset');
sys = newmodel('L3T3_PSK', outdir, c.STOP, c.TS, 'FixedStepDiscrete');
B = 'Bernoulli Binary Generator (Source)';

addlut(sys, '1-D Lookup Table1', '[-1,1]', '[0,1]', [285 413 398 533]);
bconn(sys, '1-D Lookup Table1/1');
addsineS(sys, 'Sine Wave (Mod)', '5000', '0', c.TS, [450 510 510 570]);
addprod(sys, 'Product (Mod)', [585 455 640 520]);
conn(sys, '1-D Lookup Table1/1', 'Product (Mod)/1');
conn(sys, 'Sine Wave (Mod)/1', 'Product (Mod)/2');

addscope(sys, 'Scope (Mod)', 2, [748 270 803 330], 'Bits (1) and PSK signal (2)', c.SPAN, true);
bconn(sys, 'Scope (Mod)/1');
conn(sys, 'Product (Mod)/1', 'Scope (Mod)/2');
addrt(sys, 'Rate Transition', c.RT, [740 655 810 720]);
addspec(sys, 'Spectrum (Mod)', [870 648 953 750], specp('Spectrum (Mod): PSK', [], c.RBW, 0, 0));
conn(sys, 'Product (Mod)/1', 'Rate Transition/1');
conn(sys, 'Rate Transition/1', 'Spectrum (Mod)/1');

receiver(sys, 'Product (Mod)', B, '10000', c, [710 540 765 600], [825 470 880 530]);

% PSK draws Scope (Product) as [PSK signal, demod product].
addscope(sys, 'Scope (Product)', 2, [945 270 1000 330], 'PSK signal (1) and PSK x carrier (2)', c.SPAN, true);
conn(sys, 'Product (Mod)/1', 'Scope (Product)/1');
conn(sys, 'Product (Demod)/1', 'Scope (Product)/2');

set_param(sys, 'Description', 'ECSE 308 L3T3 Part 2: binary PSK, 1 kb/s on a 2 kHz carrier.');
audit();
libraries(sys);
compiles(sys);
savemodel(sys, outdir);
end

% =====================================================================
% Binary FSK (pages 15-16)
% =====================================================================
function buildfsk(outdir)
c = consts();
expect('reset');
sys = newmodel('L3T3_FSK', outdir, c.STOP, c.TS, 'FixedStepDiscrete');
B = 'Bernoulli Binary Generator (Source)';

addlut(sys, '1-D Lookup Table (Mod)', '[-1,1]', '[0,1]', [248 488 333 578]);
addrt(sys, 'Rate Transition', c.TS, [405 505 465 565]);
bconn(sys, '1-D Lookup Table (Mod)/1');
conn(sys, '1-D Lookup Table (Mod)/1', 'Rate Transition/1');

% Switch: top input when the bit is +1 (2.5 kHz), bottom input when -1 (3.5 kHz).
addsineS(sys, 'Sine Wave (Mod//Lower)', '4000', '0', c.TS, [448 405 495 450]);
addsineS(sys, 'Sine Wave (Mod//Upper)', '2857', '0', c.TS, [448 648 495 693]);
s = addb(sys, 'Switch', 'Switch', {'simulink/Signal Routing/Switch', 'built-in/Switch'}, [563 505 638 565]);
setp(s, 'u2 > Threshold', {'Criteria'},  {'Criteria'});
setp(s, '0',              {'Threshold'}, {'Threshold'});
conn(sys, 'Sine Wave (Mod//Lower)/1', 'Switch/1');
conn(sys, 'Rate Transition/1', 'Switch/2');
conn(sys, 'Sine Wave (Mod//Upper)/1', 'Switch/3');

addscope(sys, 'Scope (Mod)', 2, [758 293 803 338], 'Bits (1) and FSK signal (2)', c.SPAN, true);
bconn(sys, 'Scope (Mod)/1');
conn(sys, 'Switch/1', 'Scope (Mod)/2');
addrt(sys, 'Rate Transition (Spectrum)', c.RT, [743 410 803 470]);
hidename([sys '/Rate Transition (Spectrum)']);
addspec(sys, 'Spectrum (Mod)', [858 400 925 485], specp('Spectrum (Mod): FSK', [], c.RBW, 0, 0));
conn(sys, 'Switch/1', 'Rate Transition (Spectrum)/1');
conn(sys, 'Rate Transition (Spectrum)/1', 'Spectrum (Mod)/1');

% Receiver: multiply by (lower - upper). A 2.5 kHz bit sums positive, a
% 3.5 kHz bit negative.
addsineS(sys, 'Sine Wave (Demod//Lower)', '4000', '0', c.TS, [563 623 608 668]);
addsineS(sys, 'Sine Wave (Demod//Upper)', '2857', '0', c.TS, [563 758 608 803]);
addsum(sys, 'Add', '+-', [683 683 728 743]);
conn(sys, 'Sine Wave (Demod//Lower)/1', 'Add/1');
conn(sys, 'Sine Wave (Demod//Upper)/1', 'Add/2');
addprod(sys, 'Product', [770 530 815 580]);
conn(sys, 'Switch/1', 'Product/1');
conn(sys, 'Add/1', 'Product/2');
addrt(sys, 'Rate Transition (I&D)', c.RT, [860 525 920 585]);
hidename([sys '/Rate Transition (I&D)']);
conn(sys, 'Product/1', 'Rate Transition (I&D)/1');

addid(sys, 'Integrate and Dump', '20', [960 518 1080 585]);
addsign(sys, 'Sign', [1140 530 1185 575]);
addlut(sys, '1-D Lookup Table (Demod)', '[0,0,1]', '[-1,0,1]', [1238 503 1320 600]);
conn(sys, 'Rate Transition (I&D)/1', 'Integrate and Dump/1');
conn(sys, 'Integrate and Dump/1', 'Sign/1');
conn(sys, 'Sign/1', '1-D Lookup Table (Demod)/1');
addscope(sys, 'Scope (Integrate and Dump)', 1, [1140 630 1185 675], 'Integrate and Dump output', c.SPAN, false);
conn(sys, 'Integrate and Dump/1', 'Scope (Integrate and Dump)/1');
addscope(sys, 'Scope (Demod)', 2, [1358 375 1403 420], 'Bits sent (1) and recovered (2)', c.SPAN, true);
bconn(sys, 'Scope (Demod)/1');
conn(sys, '1-D Lookup Table (Demod)/1', 'Scope (Demod)/2');

set_param(sys, 'Description', 'ECSE 308 L3T3 Part 2: binary FSK, 1 kb/s, 2.5 kHz for a 1 and 3.5 kHz for a 0.');
audit();
libraries(sys);
compiles(sys);
savemodel(sys, outdir);
end

% =====================================================================
% 4-QAM (pages 17-18)
% =====================================================================
function buildqam4(outdir)
c = consts();
expect('reset');
sys = newmodel('L3T3_4QAM', outdir, c.STOP, c.TS, 'FixedStepDiscrete');

r = addb(sys, 'Random Integer Generator (Source)', 'Random Integer Generator', { ...
    'commrandsrc/Random Integer Generator', 'commsrc2/Random Integer Generator', ...
    'commlib/Comm Sources/Random Data Sources/Random Integer Generator'}, [60 360 195 435]);
setp(r, '4',  {'SetSize', 'M'},    {'Set size', 'M-ary number'});
setp(r, c.TB, {'SampleTime', 'Ts'}, {'Sample time'});
i2b = addb(sys, 'Integer to Bit Converter', 'Integer to Bit Converter', { ...
    'commutil2/Integer to Bit Converter', 'commutil/Integer to Bit Converter', ...
    'commlib/Utility Blocks/Integer to Bit Converter'}, [258 360 393 435]);
setp(i2b, '2', {'nbits', 'nBits', 'NumBitsPerInteger'}, {'Number of bits'});
dm = addb(sys, 'Demux', 'Demux', {'simulink/Signal Routing/Demux', 'built-in/Demux'}, [453 345 463 450]);
setp(dm, '2', {'Outputs'}, {'Number of outputs'});
conn(sys, 'Random Integer Generator (Source)/1', 'Integer to Bit Converter/1');
conn(sys, 'Integer to Bit Converter/1', 'Demux/1');

A = '[-sqrt(0.5),sqrt(0.5)]';
addlut(sys, '1-D Lookup Table (I)', A, '[0,1]', [593 225 720 345]);
addlut(sys, '1-D Lookup Table (Q)', A, '[0,1]', [593 458 720 578]);
conn(sys, 'Demux/1', '1-D Lookup Table (I)/1');
conn(sys, 'Demux/2', '1-D Lookup Table (Q)/1');

% Offset 1250 of 5000 samples = a quarter period, so Sine Wave (I) is a cosine.
addsineS(sys, 'Sine Wave (I)', '5000', '1250', c.TS, [773 318 818 363]);
addsineS(sys, 'Sine Wave (Q)', '5000', '0',    c.TS, [773 548 818 593]);
addprod(sys, 'Product (I)', [938 275 983 320]);
addprod(sys, 'Product (Q)', [938 505 983 550]);
conn(sys, '1-D Lookup Table (I)/1', 'Product (I)/1');
conn(sys, 'Sine Wave (I)/1', 'Product (I)/2');
conn(sys, '1-D Lookup Table (Q)/1', 'Product (Q)/1');
conn(sys, 'Sine Wave (Q)/1', 'Product (Q)/2');
addsum(sys, 'Add', '+-', [1100 410 1158 470]);
conn(sys, 'Product (I)/1', 'Add/1');
conn(sys, 'Product (Q)/1', 'Add/2');

addscope(sys, 'Scope (4QAM)', 3, [1240 290 1300 340], ...
    '4-QAM signal (1), I level (2), Q level (3)', c.SPAN, true);
conn(sys, 'Add/1', 'Scope (4QAM)/1');
conn(sys, '1-D Lookup Table (I)/1', 'Scope (4QAM)/2');
conn(sys, '1-D Lookup Table (Q)/1', 'Scope (4QAM)/3');
addrt(sys, 'Rate Transition', c.RT, [1235 490 1295 550]);
addspec(sys, 'Spectrum (4QAM)', [1340 480 1425 585], specp('Spectrum (4QAM)', [], c.RBW, 0, 0));
conn(sys, 'Add/1', 'Rate Transition/1');
conn(sys, 'Rate Transition/1', 'Spectrum (4QAM)/1');

set_param(sys, 'Description', 'ECSE 308 L3T3 Part 2: 4-QAM, 2 bits per 1 ms symbol, I cos - Q sin on 2 kHz.');
audit();
libraries(sys);
compiles(sys);
savemodel(sys, outdir);
end

% =====================================================================
% The ASK / PSK receiver: x carrier, Integrate and Dump, Sign, table, scope
% =====================================================================
function receiver(sys, txblk, B, n, c, sinepos, prodpos)
addsineS(sys, 'Sine Wave (Demod)', '5000', '0', c.TS, sinepos);
addprod(sys, 'Product (Demod)', prodpos);
conn(sys, [txblk '/1'], 'Product (Demod)/1');
conn(sys, 'Sine Wave (Demod)/1', 'Product (Demod)/2');

x = prodpos(3) + 75;
y = prodpos(2) - 5;
addid(sys, 'Integrate and Dump', n, [x y x+150 y+90]);
addsign(sys, 'Sign', [x+190 y+15 x+245 y+65]);
addlut(sys, '1-D Lookup Table', '[0,0,1]', '[-1,0,1]', [x+300 y-15 x+420 y+105]);
conn(sys, 'Product (Demod)/1', 'Integrate and Dump/1');
conn(sys, 'Integrate and Dump/1', 'Sign/1');
conn(sys, 'Sign/1', '1-D Lookup Table/1');

addscope(sys, 'Scope (Demod)', 2, [x+480 y-80 x+545 y-15], 'Bits sent (1) and recovered (2)', c.SPAN, true);
bconn(sys, 'Scope (Demod)/1');
conn(sys, '1-D Lookup Table/1', 'Scope (Demod)/2');
end

% =====================================================================
% Block helpers (the same set in all three L3T3 build scripts)
% =====================================================================
function b = addsineT(sys, name, amp, w, ts, pos)
% Simulink Sine Wave, time based, frequency in rad/s as the handout prints it.
b = addb(sys, name, 'Sine Wave', {'simulink/Sources/Sine Wave', 'built-in/Sin'}, pos);
if isempty(b), return, end
setp(b, 'Time based',          {'SineType'},   {'Sine type'});
setp(b, 'Use simulation time', {'TimeSource'}, {'^Time'}, true);
setp(b, amp, {'Amplitude'},  {'Amplitude'});
setp(b, '0', {'Bias'},       {}, true);
setp(b, w,   {'Frequency'},  {'Frequency'});
setp(b, '0', {'Phase'},      {'Phase'});
setp(b, ts,  {'SampleTime'}, {'Sample time'});
end

function b = addsineS(sys, name, nper, offset, ts, pos)
% Simulink Sine Wave, sample based: sin(2*pi*(k + offset)/nper), one value
% every ts seconds, so its frequency is 1/(nper*ts).
b = addb(sys, name, 'Sine Wave', {'simulink/Sources/Sine Wave', 'built-in/Sin'}, pos);
if isempty(b), return, end
% Sample time first: the block refuses "Sample based" while it is still 0.
setp(b, ts,     {'SampleTime'}, {'Sample time'});
setp(b, 'Sample based', {'SineType'},   {'Sine type'});
setp(b, '1',    {'Amplitude'},  {'Amplitude'});
setp(b, '0',    {'Bias'},       {}, true);
setp(b, nper,   {'Samples'},    {'Samples per period'});
setp(b, offset, {'Offset'},     {'offset samples'});
end

function b = addpulse(sys, name, type, period, width, delay, ts, pos)
% Simulink Pulse Generator. ts is only used when the pulse is sample based.
b = addb(sys, name, 'Pulse Generator', ...
    {'simulink/Sources/Pulse Generator', 'built-in/DiscretePulseGenerator'}, pos);
if isempty(b), return, end
setp(b, type, {'PulseType'}, {'Pulse type'});
setp(b, 'Use simulation time', {'TimeSource'}, {'^Time'}, true);
setp(b, '1',    {'Amplitude'},  {'Amplitude'});
% Width first, quietly: the period is refused while the old width is longer.
setp(b, width,  {'PulseWidth'}, {'Pulse Width'}, true);
setp(b, period, {'Period'},     {'Period'});
setp(b, width,  {'PulseWidth'}, {'Pulse Width'});
setp(b, delay,  {'PhaseDelay'}, {'Phase delay'});
if ~isempty(ts)
    setp(b, ts, {'SampleTime'}, {'Sample time'});
end
end

function b = addprod(sys, name, pos)
b = addb(sys, name, 'Product', {'simulink/Math Operations/Product', 'built-in/Product'}, pos);
setp(b, '2', {'Inputs'}, {'Number of inputs'}, true);
end

function b = addsum(sys, name, signs, pos)
b = addb(sys, name, 'Add', {'simulink/Math Operations/Add', 'built-in/Sum'}, pos);
setp(b, signs,         {'Inputs'},    {}, true);
setp(b, 'rectangular', {'IconShape'}, {}, true);
end

function b = addgain(sys, name, g, pos)
b = addb(sys, name, 'Gain', {'simulink/Math Operations/Gain', 'built-in/Gain'}, pos);
setp(b, g, {'Gain'}, {'Gain'});
end

function b = addconst(sys, name, v, pos)
b = addb(sys, name, 'Constant', {'simulink/Sources/Constant', 'built-in/Constant'}, pos);
setp(b, v, {'Value'}, {'Constant value'});
end

function b = addsign(sys, name, pos)
b = addb(sys, name, 'Sign', {'simulink/Math Operations/Sign', 'built-in/Signum'}, pos);
end

function b = addlut(sys, name, tbl, bp, pos)
% 1-D Lookup Table with explicit breakpoints, as every table in this lab is.
b = addb(sys, name, '1-D Lookup Table', ...
    {'simulink/Lookup Tables/1-D Lookup Table', 'built-in/Lookup_n-D'}, pos);
if isempty(b), return, end
setp(b, 'Explicit values', {'BreakpointsSpecification'}, {'Breakpoints specification'}, true);
setp(b, tbl, {'Table'}, {'Table data'});
setp(b, bp,  {'BreakpointsForDimension1'}, {'Breakpoints 1'});
end

function b = adddisp(sys, name, pos)
b = addb(sys, name, 'Display', {'simulink/Sinks/Display', 'built-in/Display'}, pos);
end

function b = addrt(sys, name, ts, pos)
b = addb(sys, name, 'Rate Transition', ...
    {'simulink/Signal Attributes/Rate Transition', 'built-in/RateTransition'}, pos);
setp(b, ts, {'OutPortSampleTime'}, {'Output port sample time'});
end

function b = addbern(sys, name, ts, spf, seed, pos)
% Communications Toolbox Bernoulli Binary Generator: random 0s and 1s.
b = addb(sys, name, 'Bernoulli Binary Generator', { ...
    'commrandsrc/Bernoulli Binary Generator', 'commsrc2/Bernoulli Binary Generator', ...
    'commlib/Comm Sources/Random Data Sources/Bernoulli Binary Generator'}, pos);
if isempty(b), return, end
setp(b, '0.5', {'ProbabilityOfZero', 'P'}, {'Probability of zero'});
if ~isempty(seed)
    setopt(b, '^(Parameter|Property)', {'SeedSource', 'seedSource'}, {'Source of initial seed'});
    setp(b, seed, {'Seed', 'seed'}, {'Initial seed'});
end
setp(b, ts,  {'SampleTime', 'Ts'}, {'Sample time'});
setp(b, spf, {'SamplesPerFrame', 'SampPerFrame'}, {'Samples per frame'});
end

function b = addawgn(sys, name, mode, snr, bits, ps, tsym, pos)
% Communications Toolbox AWGN Channel in Eb/No or Es/No mode, seed 67.
% Current releases build this block on comm.AWGNChannel, whose fields are
% NoiseMethod, EbNo, EsNo, BitsPerSymbol, SignalPower, SamplesPerSymbol,
% RandomStream and Seed. The old names (noiseMode, EbNodB, ...) are still
% accepted but hidden and ignored, so the new names are tried first. There is
% no "symbol period" any more: one sample per symbol says the same thing.
b = addb(sys, name, 'AWGN Channel', ...
    {'commchan3/AWGN Channel', 'commlib/Channels/AWGN Channel'}, pos);
if isempty(b), return, end
if ~isempty(pname(b, {'RandomStream'}, {}))
    setopt(b, 'seed', {'RandomStream'}, {});
    setp(b, '67', {'Seed'}, {});
else
    setp(b, '67', {'seed'}, {'Initial seed'});
end
if strcmp(mode, 'Eb/No')
    setopt(b, 'Eb/No', {'NoiseMethod', 'noiseMode'}, {'^Mode'});
    setp(b, snr,  {'EbNo', 'EbNodB'},            {'Eb/No'});
    setp(b, bits, {'BitsPerSymbol', 'bitsPerSym'}, {'bits per symbol'});
else
    setopt(b, 'Es/No', {'NoiseMethod', 'noiseMode'}, {'^Mode'});
    setp(b, snr, {'EsNo', 'EsNodB'}, {'Es/No'});
end
setp(b, ps, {'SignalPower', 'Ps'}, {'Input signal power'});
if ~isempty(pname(b, {'SamplesPerSymbol'}, {}))
    setp(b, '1', {'SamplesPerSymbol'}, {});
else
    setp(b, tsym, {'Tsym'}, {'Symbol period'});
end
end

function b = adderr(sys, name, delay, pos)
% Error Rate Calculation: output [BER; errors; bits compared] to its port,
% stop the run at 200 errors or after 1e6 bits.
b = addb(sys, name, 'Error Rate Calculation', { ...
    'commsink2/Error Rate Calculation', 'commlib/Comm Sinks/Error Rate Calculation'}, pos);
if isempty(b), return, end
setp(b, delay, {'N'}, {'Receive delay'});
setopt(b, '^Port', {'PMode'}, {'Output data'});
setp(b, 'on',  {'stop'},    {'Stop simulation'});
setp(b, '200', {'numErr'},  {'Target number of errors'});
setp(b, '1e6', {'maxBits'}, {'Maximum number of symbols'});
end

function b = addsh(sys, name, pos)
% DSP System Toolbox Sample and Hold: holds the input at each rising edge of
% the trigger.
b = addb(sys, name, 'Sample and Hold', ...
    {'dspsigops/Sample and Hold', 'dsp_lib/Signal Operations/Sample and Hold'}, pos);
setopt(b, '^Rising', {'trig', 'TriggerType'}, {'Trigger type'}, true);
end

function b = addid(sys, name, n, pos)
% Communications Toolbox Integrate and Dump: adds up n input samples (one
% bit), outputs the total, starts again.
b = addb(sys, name, 'Integrate and Dump', ...
    {'commfilt2/Integrate and Dump', 'commlib/Comm Filters/Integrate and Dump'}, pos);
if isempty(b), return, end
setopt(b, 'Elements as channels|sample based', {'InputProcessing'}, {'Input processing'}, true);
setp(b, n,     {'N', 'IntegrationPeriod'}, {'Integration period'});
setp(b, '0',   {'offset', 'Offset'},       {'^Offset'}, true);
setp(b, 'off', {'outputIntermediate', 'OutputIntermediateValues'}, {'intermediate'}, true);
end

function b = addbutter(sys, name, type, edges, order, pos)
% DSP System Toolbox Analog Filter Design, Butterworth. Filter type first:
% which passband-edge fields exist depends on it.
b = addb(sys, name, 'Analog Filter Design', { ...
    'dspfdesign/Analog Filter Design', 'dsparch4/Analog Filter Design', ...
    'dsp_lib/Filtering/Filter Designs/Analog Filter Design'}, pos);
setp(b, 'Butterworth', {'method'},   {'Design method'});
setp(b, type,          {'filttype'}, {'Filter type'});
setp(b, order,         {'N'},        {'Filter order'});
if numel(edges) == 2
    setp(b, edges{1}, {'Wlo'}, {'Lower passband edge'});
    setp(b, edges{2}, {'Whi'}, {'Upper passband edge'});
else
    setp(b, edges{1}, {'Wlo'}, {'^Passband edge'});
end
end

function b = addscope(sys, name, nin, pos, ttl, span, stacked)
% DSP System Toolbox Time Scope. stacked: one plot per input, top to bottom,
% instead of all inputs on one plot.
b = addb(sys, name, 'Time Scope', ...
    {'dspsnks4/Time Scope', 'dsp_lib/Sinks/Time Scope', 'simulink/Sinks/Scope'}, pos);
if isempty(b), return, end
if nin > 1
    try
        set_param(b, 'NumInputPorts', num2str(nin));
    catch ME
        note(sprintf('%s: set Number of input ports to %d by hand (%s)', name, nin, oneline(ME.message)));
    end
end
pairs = {'?Title', ttl, '?ShowGrid', true, '?ShowLegend', true, ...
    'TimeSpanOverrunAction', {'Scroll', 'scroll'}, 'TimeSpan', span};
if stacked && nin > 1
    pairs = [pairs, {'?LayoutDimensions', [nin 1]}];
end
cfgspec(b, pairs);
end

function b = addspec(sys, name, pos, pairs)
b = addb(sys, name, 'Spectrum Analyzer', ...
    {'dspsnks4/Spectrum Analyzer', 'dsp_lib/Sinks/Spectrum Analyzer', 'built-in/SpectrumAnalyzer'}, pos);
cfgspec(b, pairs);
end

function pairs = specp(ttl, span, rbw, npeaks, minh, ylims)
% Two-sided power spectrum in dBm (the professor's preference). span empty =
% the full span the sample rate allows; [f1 f2] = start and stop in Hz.
% npeaks 0 = peak finder off.
pairs = {'Title', ttl, '?ShowLegend', true, ...
    'SpectrumType', {'Power', 'power'}, 'SpectrumUnits', 'dBm', ...
    'PlotAsTwoSidedSpectrum', true};
if isempty(span)
    pairs = [pairs, {'FrequencySpan', {'Full', 'full'}}];
else
    pairs = [pairs, {'FrequencySpan', {'Start and stop frequencies', 'start-and-stop-frequencies'}, ...
        'StartFrequency', span(1), 'StopFrequency', span(2)}];
end
pairs = [pairs, { ...
    '?FrequencyResolutionMethod', {'RBW', 'rbw'}, ...
    'RBWSource', {'Property', 'property'}, 'RBW', rbw, ...
    'AveragingMethod', {'Running', 'running'}, ...
    {'SpectralAverages', 'NumSpectralAverages'}, 4}];
if npeaks > 0
    pairs = [pairs, { ...
        {'PeakFinder.Enable', 'PeakFinder.Enabled'}, true, ...
        'PeakFinder.NumPeaks', npeaks, 'PeakFinder.LabelPeaks', true, ...
        '?PeakFinder.MinHeight', minh}];
end
% A spectrum of exact sine lines has a floor near -300 dBm, which squashes
% every line to the same height; ylims zooms to where the lines are.
if nargin > 5 && ~isempty(ylims)
    pairs = [pairs, {'?YLimits', ylims}];
end
end

function hidename(blk)
if isempty(blk), return, end
try %#ok<TRYNC>
    set_param(blk, 'ShowName', 'off');
end
end

% =====================================================================
% Checks
% =====================================================================
function checkproducts()
need = {'simulink', 'Simulink'; 'dsp', 'DSP System Toolbox'; ...
        'comm', 'Communications Toolbox'; 'signal', 'Signal Processing Toolbox'};
for k = 1:size(need, 1)
    if isempty(ver(need{k, 1}))
        note(sprintf('%s is not available in this session. Blocks from it will be missing.', need{k, 2}));
    end
end
% Load the libraries up front so their block paths resolve.
for lib = {'dspsrcs4', 'dsparch4', 'dspsnks4', 'dspsigops', 'dspquant2', 'dspfdesign', ...
           'commrandsrc', 'commsrc2', 'commsink2', 'commchan3', 'commfilt2', ...
           'commutil2', 'commdigbbndam3'}
    try %#ok<TRYNC>
        load_system(lib{1});
    end
end
end

function audit()
% Read back every value setp wrote. Nothing here trusts that set_param
% "worked" because it did not throw: a later field can quietly reset an
% earlier one.
w = expect('get');
fprintf('\n  every parameter the script set, read back from the block\n');
bad = 0;
for i = 1:size(w, 1)
    [blk, prm, want] = w{i, :};
    got = getp(blk, {prm});
    ok = strcmpi(squash(got), squash(want));
    mark = 'ok   ';
    if ~ok, mark = 'CHECK'; bad = bad + 1; end
    fprintf('    %s %-34s %-24s %s\n', mark, short(blk), prm, got);
    if ~ok
        note(sprintf('%s: %s reads "%s", it should be %s. Open the block and set it.', ...
            short(blk), prm, got, want));
    end
end
fprintf('  %d of %d read back as set\n\n', size(w, 1) - bad, size(w, 1));
end

function libraries(sys)
% Say where every block came from: DSP System Toolbox, Communications
% Toolbox, or plain Simulink.
blks = find_system(sys, 'SearchDepth', 1, 'Type', 'block');
fprintf('  which library each block came from\n');
for i = 1:numel(blks)
    if strcmp(blks{i}, sys), continue, end
    ref = '';
    try %#ok<TRYNC>
        ref = get_param(blks{i}, 'ReferenceBlock');
    end
    if isempty(ref)
        ref = ['Simulink built-in (' get_param(blks{i}, 'BlockType') ')'];
    end
    top = strtok(ref, '/');
    if strncmp(top, 'dsp', 3)
        tag = 'DSP ';
    elseif strncmp(top, 'comm', 4)
        tag = 'Comm';
    else
        tag = 'Simulink';
    end
    fprintf('    %-8s %-34s %s\n', tag, short(blks{i}), oneline(ref));
end
fprintf('\n');
end

function s = short(blk)
s = regexprep(oneline(blk), '^[^/]*/', '');
end

function [ok, msg] = tryupdate(sys)
% The same as Ctrl+D in the editor: resolves sample times, sizes and rates,
% and throws on anything that would stop the run.
try
    set_param(sys, 'SimulationCommand', 'update');
    ok = true;
    msg = '';
catch ME
    ok = false;
    msg = errtext(ME);
end
end

function compiles(sys)
[ok, msg] = tryupdate(sys);
if ok
    fprintf('  diagram update (Ctrl+D): OK, %s compiles\n\n', sys);
else
    note(sprintf('%s does not compile yet: %s', sys, msg));
end
end

function s = errtext(ME)
% An update error is often "multiple causes"; the useful text is in the causes.
s = oneline(ME.message);
for k = 1:numel(ME.cause)
    s = [s ' | ' errtext(ME.cause{k})]; %#ok<AGROW>
end
end

function s = squash(s)
s = lower(regexprep(char(s), '\s+', ''));
end

function savemodel(sys, outdir)
save_system(sys, fullfile(outdir, [sys '.slx']));
fprintf('saved %s\n\n', fullfile(outdir, [sys '.slx']));
end

% =====================================================================
% Plumbing
% =====================================================================
function sys = newmodel(name, outdir, stoptime, ts, solver)
% Any earlier copy of the model is moved to models/_previous, not deleted.
if bdIsLoaded(name), close_system(name, 0); end
f = fullfile(outdir, [name '.slx']);
if exist(f, 'file')
    prev = fullfile(outdir, '_previous');
    if ~exist(prev, 'dir'), mkdir(prev); end
    stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    movefile(f, fullfile(prev, sprintf('%s_%s.slx', name, stamp)));
end
new_system(name);
sys = name;
set_param(sys, 'SolverType', 'Fixed-step', 'Solver', solver, ...
    'FixedStep', ts, 'StopTime', stoptime);
% One task for every rate, so a slow signal can feed a fast block directly,
% as the handout's diagrams do everywhere.
try
    set_param(sys, 'EnableMultiTasking', 'off');
catch
    try %#ok<TRYNC>
        set_param(sys, 'SolverMode', 'SingleTasking');
    end
end
try %#ok<TRYNC>
    set_param(sys, 'AutoInsertRateTranBlk', 'on');
end
end

function b = addb(sys, name, libname, cands, pos, quiet)
% quiet: the caller has its own fallback, so do not search every library or
% complain when none of cands exists.
if nargin < 6, quiet = false; end
b = '';
dst = [sys '/' name];
for k = 1:numel(cands)
    try
        add_block(cands{k}, dst, 'Position', pos);
        b = dst;
        return
    catch
    end
end
if quiet, return, end
src = findlib(libname);
if ~isempty(src)
    try
        add_block(src, dst, 'Position', pos);
        b = dst;
        return
    catch
    end
end
note(sprintf('block "%s" not found in any library, add it by hand as "%s"', libname, name));
end

function p = findlib(libname)
% Find a block by name in the installed libraries. The top-level libraries
% first; then every library file of the Communications and DSP toolboxes,
% because commlib only opens its sublibraries on a double-click and
% find_system cannot see through that.
persistent found
if isempty(found), found = containers.Map(); end
if isKey(found, libname), p = found(libname); return, end
p = '';
words = strsplit(strtrim(libname));
pat = ['^' strjoin(words, '[ \n]+') '$'];
tops = {'simulink', 'dsp_lib', 'commlib'};
for k = 1:numel(tops)
    p = searchlib(tops{k}, pat);
    if ~isempty(p), found(libname) = p; return, end
end
for tb = {'comm', 'dsp'}
    files = [dir(fullfile(matlabroot, 'toolbox', tb{1}, '**', '*.slx')); ...
             dir(fullfile(matlabroot, 'toolbox', tb{1}, '**', '*.mdl'))];
    for k = 1:numel(files)
        [~, nm] = fileparts(files(k).name);
        if isempty(regexp(nm, '^(comm|dsp)', 'once')) || ...
                ~isempty(regexpi(files(k).folder, 'example|demo|test', 'once'))
            continue
        end
        p = searchlib(nm, pat);
        if ~isempty(p)
            fprintf('  (found "%s" in %s)\n', libname, nm);
            found(libname) = p;
            return
        end
    end
end
end

function p = searchlib(lib, pat)
p = '';
try
    wasloaded = bdIsLoaded(lib);
    load_system(lib);
    if ~bdIsLibrary(lib)
        if ~wasloaded, close_system(lib, 0); end
        return
    end
    r = find_system(lib, 'MatchFilter', @Simulink.match.allVariants, ...
        'FollowLinks', 'on', 'LookUnderMasks', 'all', 'RegExp', 'on', 'Name', pat);
    if ~isempty(r), p = r{1}; end
catch
end
end

function nm = pname(blk, names, prompts)
% The dialog name of a parameter: one of names if the block has it, else the
% mask variable whose prompt matches one of prompts.
nm = '';
known = {};
try
    dp = get_param(blk, 'DialogParameters');
    if isstruct(dp), known = fieldnames(dp); end
catch
end
for k = 1:numel(names)
    if any(strcmp(known, names{k})), nm = names{k}; return, end
end
[mp, mn] = prompts_of(blk);
for i = 1:numel(mp)
    for k = 1:numel(prompts)
        if ~isempty(regexpi(mp{i}, prompts{k}, 'once'))
            nm = mn{i};
            return
        end
    end
end
end

function [mp, mn] = prompts_of(blk)
% The prompt text of every dialog field and its name: from the mask if the
% block has one, else from DialogParameters (MATLAB System blocks).
mp = {};
mn = {};
try
    mp = get_param(blk, 'MaskPrompts');
    mn = get_param(blk, 'MaskNames');
catch
end
if isempty(mp)
    try
        dp = get_param(blk, 'DialogParameters');
        f = fieldnames(dp);
        for i = 1:numel(f)
            if isfield(dp.(f{i}), 'Prompt')
                mp{end+1} = dp.(f{i}).Prompt; %#ok<AGROW>
                mn{end+1} = f{i};             %#ok<AGROW>
            end
        end
    catch
    end
end
end

function setopt(blk, pat, names, prompts, quiet)
% Set a drop-down parameter to the option that matches pat, whatever the
% exact wording (and spacing) of that option is in this release.
if isempty(blk), return, end
if nargin < 5, quiet = false; end
nm = pname(blk, names, prompts);
if isempty(nm)
    if ~quiet
        note(sprintf('%s: no "%s" field found; set it to "%s" by hand', short(blk), names{1}, pat));
    end
    return
end
opts = {};
try
    dp = get_param(blk, 'DialogParameters');
    opts = dp.(nm).Enum;
catch
end
hit = '';
for i = 1:numel(opts)
    if ~isempty(regexpi(opts{i}, pat, 'once')), hit = opts{i}; break, end
end
if isempty(hit)
    if ~quiet
        note(sprintf('%s: "%s" has no option like "%s" (it has: %s)', short(blk), nm, pat, ...
            strjoin(cellfun(@char, opts, 'UniformOutput', false), ' / ')));
    end
    return
end
setp(blk, hit, {nm}, {}, quiet);
end

function setp(blk, val, names, prompts, quiet)
% Set one parameter, trying exact dialog names first, then matching the mask
% prompt text, so a renamed mask variable does not stop the build.
if isempty(blk), return, end
if nargin < 5, quiet = false; end
known = {};
try
    dp = get_param(blk, 'DialogParameters');
    if isstruct(dp), known = fieldnames(dp); end
catch
end
why = '';
for k = 1:numel(names)
    if any(strcmp(known, names{k}))
        try
            set_param(blk, names{k}, val);
            expect('add', blk, names{k}, val);
            return
        catch ME
            why = oneline(ME.message);
        end
    end
end
[mp, mn] = prompts_of(blk);
for i = 1:numel(mp)
    for k = 1:numel(prompts)
        if ~isempty(regexpi(mp{i}, prompts{k}, 'once'))
            try
                set_param(blk, mn{i}, val);
                expect('add', blk, mn{i}, val);
                return
            catch ME
                why = oneline(ME.message);
            end
        end
    end
end
if ~quiet
    label = names;
    if isempty(label), label = prompts; end
    if isempty(why)
        why = sprintf('no such dialog field; it has: %s', strjoin(known(:)', ', '));
    end
    note(sprintf('%s: "%s" = %s not set (%s)', short(blk), label{1}, val, why));
end
end

function v = getp(blk, names)
v = '';
for k = 1:numel(names)
    try
        v = char(get_param(blk, names{k}));
        if ~isempty(v), return, end
    catch
    end
end
if isempty(v), v = '(unreadable)'; end
end

function cfgspec(blk, pairs)
% Push display settings into a Scope, Spectrum Analyzer or Constellation
% Diagram. A name or a value may be a cell of alternatives; a leading '?'
% means optional.
if isempty(blk), return, end
try
    cfg = get_param(blk, 'ScopeConfiguration');
catch
    note(sprintf('%s: no ScopeConfiguration, set its display options from the toolstrip', short(blk)));
    return
end
for i = 1:2:numel(pairs)
    prop = pairs{i};
    val  = pairs{i+1};
    if ischar(prop), prop = {prop}; end
    if ~iscell(val), val = {val}; end
    optional = strncmp(prop{1}, '?', 1);
    if optional, prop{1} = prop{1}(2:end); end
    ok = false;
    why = '';
    for k = 1:numel(prop)
        parts = strsplit(prop{k}, '.');
        for v = 1:numel(val)
            tries = val(v);
            if isnumeric(val{v}) && isscalar(val{v})
                tries{end+1} = num2str(val{v}); %#ok<AGROW>
            end
            for t = 1:numel(tries)
                try
                    if numel(parts) == 1
                        cfg.(parts{1}) = tries{t};
                    else
                        cfg.(parts{1}).(parts{2}) = tries{t};
                    end
                    ok = true;
                catch ME
                    why = oneline(ME.message);
                end
                if ok, break, end
            end
            if ok, break, end
        end
        if ok, break, end
    end
    if ~ok && ~optional
        note(sprintf('%s: display option "%s" not set (%s)', short(blk), prop{1}, why));
    end
end
end

function conn(sys, src, dst)
try
    drawline(sys, src, dst);
catch ME
    note(sprintf('%s: connect %s -> %s by hand (%s)', sys, src, dst, oneline(ME.message)));
end
end

function connany(sys, src, dsts)
% Connect to the first of several port names that exists, e.g. a trigger
% port that is "Trigger" on one release and port 2 on another.
why = '';
for k = 1:numel(dsts)
    try
        drawline(sys, src, dsts{k});
        return
    catch ME
        why = oneline(ME.message);
    end
end
note(sprintf('%s: connect %s -> %s by hand (%s)', sys, src, dsts{1}, why));
end

function drawline(sys, src, dst)
% A real, visible wire. With autorouting on, this release may show a long
% wire as a name label at its end instead of a line, so the wire is drawn
% plainly and then tidied into right angles.
h = add_line(sys, src, dst);
try %#ok<TRYNC>
    Simulink.BlockDiagram.routeLine(h);
end
end

function report()
m = note('get');
if isempty(m)
    fprintf('nothing outstanding. The models are ready to run.\n');
    return
end
fprintf('\n%d thing(s) need you:\n', numel(m));
for k = 1:numel(m)
    fprintf('  %d. %s\n', k, m{k});
end
fprintf('\n');
end

function s = oneline(msg)
s = strtrim(regexprep(msg, '\s+', ' '));
end

function out = expect(cmd, blk, prm, val)
% Every value setp wrote, so audit can read each one back. A later write to
% the same field replaces the earlier one.
persistent w
if isempty(w), w = cell(0, 3); end
out = {};
switch cmd
    case 'reset', w = cell(0, 3);
    case 'get',   out = w;
    case 'add'
        hit = strcmp(w(:, 1), blk) & strcmp(w(:, 2), prm);
        w(hit, :) = [];
        w(end+1, :) = {blk, prm, val};
end
end

function out = note(msg)
persistent list
if isempty(list), list = {}; end
out = {};
switch msg
    case 'reset', list = {}; expect('reset');
    case 'get',   out = list;
    otherwise,    list{end+1} = msg;
end
end

% =====================================================================
% BER sweeps: run a copy of a saved model at each SNR, read the Error Rate
% Calculation output, never touch the model itself
% =====================================================================
function [tmp, f] = sweepcopy(src)
% Load a temporary copy of a saved model, with its scopes, spectra and
% constellation commented out (they only slow the runs down) and a To
% Workspace block on the Error Rate Calculation output.
tmp = 'L3T3_sweep_tmp';
if bdIsLoaded(tmp), close_system(tmp, 0); end
f = fullfile(tempdir, [tmp '.slx']);
copyfile(src, f, 'f');
load_system(f);
sinks = find_system(tmp, 'SearchDepth', 1, 'RegExp', 'on', 'Name', '^(Scope|Spectrum|Constellation)');
for k = 1:numel(sinks)
    set_param(sinks{k}, 'Commented', 'on');
end
add_block('simulink/Sinks/To Workspace', [tmp '/BER log'], ...
    'VariableName', 'L3T3_ber', 'SaveFormat', 'Array', 'MaxDataPoints', '1', ...
    'Position', [20 20 80 50]);
add_line(tmp, 'Error Rate Calculation/1', 'BER log/1');
end

function v = runber(tmp)
% One run; returns [BER errors bits] from the last Error Rate output.
out = sim(tmp, 'ReturnWorkspaceOutputs', 'on');
r = double(out.get('L3T3_ber'));
if ndims(r) == 3
    v = reshape(r(:, :, end), [], 1);
elseif size(r, 2) == 3
    v = r(end, :).';
else
    v = r(:, end);
end
end

function dropcopy(tmp, f)
if bdIsLoaded(tmp), close_system(tmp, 0); end
if exist(f, 'file'), delete(f); end
end

function saveplot(fig, base, rows, header, outdir)
% PNG of the plot into figures/, the numbers into models/ as CSV.
fd = fullfile(pwd, 'figures');
if ~exist(fd, 'dir'), mkdir(fd); end
try
    exportgraphics(fig, fullfile(fd, [base '.png']), 'Resolution', 150);
    fprintf('\n  plot saved to %s\n', fullfile(fd, [base '.png']));
catch ME
    note(sprintf('plot not saved (%s); screenshot the figure instead', oneline(ME.message)));
end
fid = fopen(fullfile(outdir, [base '.csv']), 'w');
if fid > 0
    fprintf(fid, '%s\n', header);
    fprintf(fid, [strjoin(repmat({'%.6g'}, 1, size(rows, 2)), ',') '\n'], rows.');
    fclose(fid);
    fprintf('  numbers saved to %s\n\n', fullfile(outdir, [base '.csv']));
end
end
