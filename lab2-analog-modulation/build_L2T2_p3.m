function build_L2T2_p3(varargin)
%BUILD_L2T2_P3  ECSE 308 L2T2 Part 3: FM transmission and reception (SNR).
%
%   build_L2T2_p3          builds models/L2T2_FM_SNR.slx (handout pages 16-18)
%   build_L2T2_p3 table    runs the model once per deviation
%                          Df = 0.1, 0.5, 1, 2, ..., 10 x fm and prints the
%                          page 19 table: carrier level, significant sideband
%                          pairs, 99% bandwidth, Carson bandwidth, and the
%                          percentage of power inside Carson's bandwidth.
%                          Also written to models/L2T2_p3_table.csv.
%
% The circuit, left to right:
%
%   Transmitter   Sine Wave (100 Hz: 1000 samples per period at 1e-5 s) ->
%                 Gain (Sensitivity Factor) = Df -> + 9000 -> integrator ->
%                 2*pi -> cos.  Carrier 9 kHz, peak deviation Df Hz.
%   Receivers     FM Demodulator (Noiseless) gets the clean signal.
%                 FM Demodulator (Noisy) gets signal + Gaussian noise
%                 (variance 1e-2) band-limited to 8-10 kHz, clipped to +-1.
%                 Each is the page 17 subsystem: Product, Saturation +-0.5,
%                 8th-order Butterworth lowpass at 200 Hz, VCO with gain 2000.
%   Meters        Pre-detection SNR = RMS(signal) / RMS(band-limited noise).
%                 Post-detection SNR = RMS(noisy output) /
%                 RMS(noisy output - noiseless output). Both in dB.
%
% Every parameter from page 18 is typed in. Things the handout leaves open:
%
%   * Solver: fixed-step ode4 at 1e-5 s. The Analog Filter Design blocks are
%     continuous-time, so a continuous solver is needed.
%   * Gain (Sensitivity Factor) starts at 100 (Df = fm, beta = 1). Change it by
%     double-clicking, exactly as in Part 2.
%   * Spectrum (Mod): two-sided (as the professor prefers), dBm, 7-11 kHz,
%     RBW 5 Hz so 100 Hz-spaced lines separate, peak finder on with its
%     threshold at -10 dBm, the handout's "significant" level. Channel
%     Measurements (Occupied BW, 99%) centred on 9 kHz, span 4 kHz.
%   * The Sine Wave is the Simulink one in sample-based mode, as the handout
%     specifies. "Samples per second: 1000" on page 18 is read as samples per
%     period, which is the field that block has.
%
% Needs Simulink, DSP System Toolbox and Signal Processing Toolbox.

MODEL = 'L2T2_FM_SNR';
TS    = '1e-5';
STOP  = '2';

note('reset');
if nargin >= 1 && strcmpi(varargin{1}, 'table')
    runtable(MODEL);
    report();
    return
end
checkproducts();
outdir = fullfile(pwd, 'models');
if ~exist(outdir, 'dir'), mkdir(outdir); end
sys = newmodel(MODEL, outdir, STOP, TS, 'ode4');

% ---- transmitter -------------------------------------------------------
addsinesb(sys, 'Sine Wave (Modulating Signal)', '1', '1000', TS, [103 298 153 350]);
addgain(sys, 'Gain (Sensitivity Factor)', '100', [225 300 275 350]);
addk(sys, 'Constant (Carrier Frequency)', '9000', [208 440 258 488]);
addsum(sys, 'Add', '++', [380 312 430 368]);
addint(sys, 'Discrete-Time Integrator', TS, [480 312 538 372]);
addgain(sys, 'Gain', '2*pi', [578 318 628 366]);
addtrig(sys, 'Trigonometric Function', 'cos', [668 318 718 366]);
conn(sys, 'Sine Wave (Modulating Signal)/1', 'Gain (Sensitivity Factor)/1', 'm');
conn(sys, 'Gain (Sensitivity Factor)/1', 'Add/1');
conn(sys, 'Constant (Carrier Frequency)/1', 'Add/2');
conn(sys, 'Add/1', 'Discrete-Time Integrator/1');
conn(sys, 'Discrete-Time Integrator/1', 'Gain/1');
conn(sys, 'Gain/1', 'Trigonometric Function/1');
logfm(sys);

% ---- noiseless receiver and the spectrum -------------------------------
mkdemod(sys, 'FM Demodulator (Noiseless)', TS, [880 308 998 378]);
addscope(sys, 'Scope (Noiseless)', 2, [1210 300 1258 358], 'Message (1) and noiseless demod (2)', 0.02);
addspec(sys, 'Spectrum (Mod)', [1365 288 1440 378], specp3());
conn(sys, 'Trigonometric Function/1', 'FM Demodulator (Noiseless)/1', 'fm');
conn(sys, 'Trigonometric Function/1', 'Spectrum (Mod)/1');
conn(sys, 'Sine Wave (Modulating Signal)/1', 'Scope (Noiseless)/1');
conn(sys, 'FM Demodulator (Noiseless)/1', 'Scope (Noiseless)/2', 'clean');

% ---- channel: band-limited noise, then the noisy receiver ---------------
addrand(sys, 'Random Source (Noise)', 1e-2, 1e-5, [700 563 760 630]);
addbutter(sys, 'Analog Filter Design', 'Bandpass', {'8000*2*pi', '10000*2*pi'}, [833 563 907 628]);
addsum(sys, 'Add (Rx)', '++', [1012 555 1062 610]);
sa = addb(sys, 'Saturation', 'Saturation', ...
    {'simulink/Discontinuities/Saturation', 'built-in/Saturate'}, [1102 560 1152 610]);
setp(sa, '1',  {'UpperLimit'}, {'Upper limit'});
setp(sa, '-1', {'LowerLimit'}, {'Lower limit'});
add_block([sys '/FM Demodulator (Noiseless)'], [sys '/FM Demodulator (Noisy)'], ...
    'Position', [1192 552 1308 622]);
addscope(sys, 'Scope (Noisy)', 1, [1382 560 1430 614], 'Noisy demod', 0.02);
conn(sys, 'Random Source (Noise)/1', 'Analog Filter Design/1');
conn(sys, 'Trigonometric Function/1', 'Add (Rx)/1');
conn(sys, 'Analog Filter Design/1', 'Add (Rx)/2', 'noise');
conn(sys, 'Add (Rx)/1', 'Saturation/1');
conn(sys, 'Saturation/1', 'FM Demodulator (Noisy)/1');
conn(sys, 'FM Demodulator (Noisy)/1', 'Scope (Noisy)/1', 'noisy');

% ---- pre-detection SNR: RMS(signal) / RMS(noise) ------------------------
addrms(sys, 'Running RMS (Signal)', [668 460 792 522]);
addrt(sys, 'RT (Noise)', TS, [832 698 898 772]);
addrms(sys, 'Running RMS (Noise)', [668 704 792 768]);
adddiv(sys, 'Divide (Pre)', '*/', [538 565 586 615]);
adddb(sys, 'dB Conversion (Pre)', [340 556 471 636]);
adddisp(sys, 'Display (Pre-detection SNR)', [103 570 250 614]);
conn(sys, 'Trigonometric Function/1', 'Running RMS (Signal)/1');
conn(sys, 'Analog Filter Design/1', 'RT (Noise)/1');
conn(sys, 'RT (Noise)/1', 'Running RMS (Noise)/1');
conn(sys, 'Running RMS (Signal)/1', 'Divide (Pre)/1');
conn(sys, 'Running RMS (Noise)/1', 'Divide (Pre)/2');
conn(sys, 'Divide (Pre)/1', 'dB Conversion (Pre)/1');
conn(sys, 'dB Conversion (Pre)/1', 'Display (Pre-detection SNR)/1', 'SNR_pre_dB');

% ---- post-detection SNR: RMS(noisy out) / RMS(noisy - noiseless) --------
addsum(sys, 'Subtract', '+-', [898 792 948 846]);
addrt(sys, 'RT (Error)', TS, [800 786 866 860]);
addrms(sys, 'Running RMS (Error)', [627 792 750 856]);
addrt(sys, 'RT (Output)', TS, [800 918 866 990]);
addrms(sys, 'Running RMS (Output)', [627 922 750 986]);
adddiv(sys, 'Divide (Post)', '/*', [505 862 553 915]);
adddb(sys, 'dB Conversion (Post)', [307 852 438 932]);
adddisp(sys, 'Display (Post-detection SNR)', [103 866 250 918]);
conn(sys, 'FM Demodulator (Noisy)/1', 'Subtract/1');
conn(sys, 'FM Demodulator (Noiseless)/1', 'Subtract/2');
conn(sys, 'Subtract/1', 'RT (Error)/1', 'error');
conn(sys, 'RT (Error)/1', 'Running RMS (Error)/1');
conn(sys, 'Running RMS (Error)/1', 'Divide (Post)/1');
conn(sys, 'FM Demodulator (Noisy)/1', 'RT (Output)/1');
conn(sys, 'RT (Output)/1', 'Running RMS (Output)/1');
conn(sys, 'Running RMS (Output)/1', 'Divide (Post)/2');
conn(sys, 'Divide (Post)/1', 'dB Conversion (Post)/1');
conn(sys, 'dB Conversion (Post)/1', 'Display (Post-detection SNR)/1', 'SNR_post_dB');

set_param(sys, 'Description', sprintf([ ...
    'ECSE 308 L2T2 Part 3: FM transmission and reception, pre/post-detection SNR.\n' ...
    'fm = 100 Hz, carrier 9 kHz, fixed-step ode4 at %s s, stop %s s.\n' ...
    'Change Gain (Sensitivity Factor) to set the peak deviation Df in Hz.\n' ...
    'build_L2T2_p3 table runs Df = 0.1 fm ... 10 fm and prints the page 19 table.'], TS, STOP));

finish(sys, outdir, MODEL);
report();
end

% =====================================================================
% The page 19 table, computed from the simulated FM signal
% =====================================================================
function runtable(MODEL)
% For each deviation, run the model, take the last second of the logged FM
% signal and read every spectral line exactly. With fm = 100 Hz and a 9 kHz
% carrier the signal repeats every 10 ms, so a 1 s FFT has 1 Hz bins with each
% line sitting on a bin and no leakage between lines.
f = fullfile(pwd, 'models', [MODEL '.slx']);
if ~exist(f, 'file')
    note(sprintf('%s does not exist yet. Run build_L2T2_p3 first.', f));
    return
end
if ~bdIsLoaded(MODEL), load_system(f); end
gblk = [MODEL '/Gain (Sensitivity Factor)'];
g0 = get_param(gblk, 'Gain');
fm = 100; fc = 9000;
betas = [0.1 0.5 1 2 3 4 5 6 7 8 9 10];
rows = zeros(numel(betas), 7);
fprintf('\n  Df/fm   Df(Hz)  carrier(dBm, 2-sided)  pairs>-10dBm  99%%BW(Hz)  Carson(Hz)  power in Carson\n');
for i = 1:numel(betas)
    Df = betas(i) * fm;
    set_param(gblk, 'Gain', num2str(Df));
    try
        out = sim(MODEL, 'ReturnWorkspaceOutputs', 'on');
        x = squeeze(double(out.logsout.getElement('fm').Values.Data));
    catch ME
        note(sprintf('Df = %g: the run or the log failed (%s)', Df, oneline(ME.message)));
        continue
    end
    fs = 1e5;
    x = x(end-fs+1:end);
    X = fft(x) / numel(x);
    P1 = 2 * abs(X(1:fs/2+1)).^2;              % one-sided power per 1 Hz bin, watts on 1 ohm
    total = sum(P1);
    n = -40:40;
    lpow = P1(fc + n*fm + 1);                   % power of the line at fc + n*fm
    K = floor(Df/fm + 1 + 1e-9);                % Carson: fc +- (Df + fm) holds lines |n| <= K
    carson = sum(lpow(abs(n) <= K)) / total;
    k = 0;
    while sum(lpow(abs(n) <= k)) < 0.99 * total && k < 40, k = k + 1; end
    pairs = sum(lpow(n >= 1) / 2 >= 1e-4);      % two-sided level above -10 dBm
    car = 10*log10(lpow(n == 0) / 2 / 1e-3);
    rows(i, :) = [betas(i) Df car pairs 2*k*fm 2*(Df+fm) 100*carson];
    fprintf('  %5.1f  %6.0f  %12.1f  %16d  %11.0f  %10.0f  %12.2f %%\n', rows(i, :));
end
set_param(gblk, 'Gain', g0);
csv = fullfile(pwd, 'models', 'L2T2_p3_table.csv');
fid = fopen(csv, 'w');
if fid > 0
    fprintf(fid, 'Df_over_fm,Df_Hz,carrier_dBm_2sided,pairs_above_m10dBm,BW99_Hz,Carson_Hz,pct_in_Carson\n');
    fprintf(fid, '%g,%g,%.2f,%d,%g,%g,%.3f\n', rows.');
    fclose(fid);
    fprintf('\n  written to %s\n', csv);
end
fprintf('  Gain (Sensitivity Factor) restored to %s\n\n', g0);
end

function logfm(sys)
% Log the FM signal (cos output) as "fm" so the table mode can read it.
try
    ph = get_param([sys '/Trigonometric Function'], 'PortHandles');
    set_param(ph.Outport(1), 'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', ...
        'DataLoggingName', 'fm');
    set_param(sys, 'SignalLogging', 'on', 'SignalLoggingName', 'logsout');
catch ME
    note(sprintf('could not turn on logging of the FM signal (%s); table mode needs it', oneline(ME.message)));
end
end

% =====================================================================
% Part 3 block helpers
% =====================================================================
function mkdemod(sys, name, TS, pos)
% The page 17 subsystem: PB in, BB out, a phase-locked loop inside.
sub = [sys '/' name];
add_block('built-in/Subsystem', sub, 'Position', pos);
add_block('built-in/Inport',  [sub '/PB'], 'Position', [40 43 70 57]);
add_block('built-in/Outport', [sub '/BB'], 'Position', [700 83 730 97]);
p = addb(sub, 'Product', 'Product', ...
    {'simulink/Math Operations/Product', 'built-in/Product'}, [200 60 240 110]);
setp(p, '2', {'Inputs'}, {'Number of inputs'}, true);
s = addb(sub, 'Saturation', 'Saturation', ...
    {'simulink/Discontinuities/Saturation', 'built-in/Saturate'}, [290 65 330 105]);
setp(s, '0.5',  {'UpperLimit'}, {'Upper limit'});
setp(s, '-0.5', {'LowerLimit'}, {'Lower limit'});
addbutter(sub, 'Analog Filter Design', 'Lowpass', {'200*2*pi'}, [390 55 490 115]);
addgain(sub, 'Gain (VCO)', '2000', [560 200 610 240]);
addk(sub, 'Constant (VCO)', '9000', [560 270 610 300]);
addsum(sub, 'Add (VCO)', '++', [480 205 520 255]);
addint(sub, 'Discrete-Time Integrator', TS, [400 210 450 250]);
addgain(sub, 'Gain (2*pi)', '2*pi', [320 210 370 250]);
addtrig(sub, 'Trigonometric Function', 'sin', [240 210 290 250]);
for nm = {'Gain (VCO)', 'Add (VCO)', 'Discrete-Time Integrator', 'Gain (2*pi)', 'Trigonometric Function'}
    flipblock([sub '/' nm{1}]);
end
conn(sub, 'PB/1', 'Product/1');
conn(sub, 'Product/1', 'Saturation/1');
conn(sub, 'Saturation/1', 'Analog Filter Design/1');
conn(sub, 'Analog Filter Design/1', 'BB/1');
conn(sub, 'Analog Filter Design/1', 'Gain (VCO)/1');
conn(sub, 'Gain (VCO)/1', 'Add (VCO)/1');
conn(sub, 'Constant (VCO)/1', 'Add (VCO)/2');
conn(sub, 'Add (VCO)/1', 'Discrete-Time Integrator/1');
conn(sub, 'Discrete-Time Integrator/1', 'Gain (2*pi)/1');
conn(sub, 'Gain (2*pi)/1', 'Trigonometric Function/1');
conn(sub, 'Trigonometric Function/1', 'Product/2', 'vco');
end

function addbutter(sys, name, type, edges, pos)
% DSP System Toolbox Analog Filter Design, Butterworth, order 8. Filter type
% first: which passband-edge fields exist depends on it.
f = addb(sys, name, 'Analog Filter Design', { ...
    'dspfdesign/Analog Filter Design', 'dsparch4/Analog Filter Design', ...
    'dsp_lib/Filtering/Filter Designs/Analog Filter Design'}, pos);
setp(f, 'Butterworth', {'method'},   {'Design method'});
setp(f, type,          {'filttype'}, {'Filter type'});
setp(f, '8',           {'N'},        {'Filter order'});
if numel(edges) == 2
    setp(f, edges{1}, {'Wlo'}, {'Lower passband edge'});
    setp(f, edges{2}, {'Whi'}, {'Upper passband edge'});
else
    setp(f, edges{1}, {'Wlo'}, {'^Passband edge'});
end
end

function addsinesb(sys, name, amp, spp, ts, pos)
% Simulink Sine Wave, sample based: frequency = 1 / (samples per period * Ts).
% Sample time first: the block refuses "Sample based" while it is still 0.
b = addb(sys, name, 'Sine Wave', {'simulink/Sources/Sine Wave', 'built-in/Sin'}, pos);
if isempty(b), return, end
setp(b, ts,  {'SampleTime'}, {'Sample time'});
setp(b, spp, {'Samples'},    {'Samples per period'});
setp(b, amp, {'Amplitude'},  {'Amplitude'});
setp(b, '0', {'Bias'},       {}, true);
setp(b, '0', {'Offset'},     {}, true);
setp(b, 'Sample based', {'SineType'}, {'Sine type'});
end

function addrt(sys, name, ts, pos)
b = addb(sys, name, 'Rate Transition', ...
    {'simulink/Signal Attributes/Rate Transition', 'built-in/RateTransition'}, pos);
setp(b, ts, {'OutPortSampleTime'}, {'Output port sample time'});
end

function addrms(sys, name, pos)
% The handout's RMS block with Running RMS on. If a release has dropped that
% mode, Moving RMS over an unlimited window is the same number.
b = addb(sys, name, 'RMS', {'dspstat3/RMS', 'dsp_lib/Statistics/RMS'}, pos, true);
if ~isempty(b)
    setp(b, 'on', {'run'}, {'Running RMS'});
    return
end
b = addb(sys, name, 'Moving RMS', {'dspstat3/Moving RMS', 'dsp_lib/Statistics/Moving RMS'}, pos);
if isempty(b), return, end
setp(b, 'off', {'SpecifyWindowLength'}, {'Specify window length'});
end

function b = addrand(sys, name, variance, ts, pos)
b = addb(sys, name, 'Random Source', ...
    {'dspsrcs4/Random Source', 'dsp_lib/Sources/Random Source'}, pos);
if isempty(b), return, end
setp(b, 'Gaussian',        {'SrcType'},                   {'Source type', 'Distribution'});
setp(b, '0',               {'MeanVal'},                   {'^Mean'}, true);
setp(b, num2str(variance), {'VarVal', 'VarianceVal'},     {'^Variance'});
setp(b, num2str(ts),       {'SampTime', 'Ts'},            {'^Sample time'});
setp(b, '1',               {'SampFrame', 'SampPerFrame'}, {'Samples per frame'}, true);
end

function adddiv(sys, name, signs, pos)
b = addb(sys, name, 'Divide', {'simulink/Math Operations/Divide', 'built-in/Product'}, pos);
setp(b, signs, {'Inputs'}, {'Number of inputs'});
end

function adddb(sys, name, pos)
% Defaults are the handout's: convert to dB, input is an amplitude, 1 ohm.
% A ratio of two RMS values in, 20*log10 of it out: the SNR in dB.
addb(sys, name, 'dB Conversion', ...
    {'dspmathops/dB Conversion', 'dsp_lib/Math Functions/Math Operations/dB Conversion'}, pos);
end

function adddisp(sys, name, pos)
addb(sys, name, 'Display', {'simulink/Sinks/Display', 'built-in/Display'}, pos);
end

function pairs = specp3()
pairs = { ...
    'Title', 'FM signal', 'ShowLegend', true, ...
    'SpectrumType', {'Power', 'power'}, 'SpectrumUnits', 'dBm', ...
    'PlotAsTwoSidedSpectrum', true, ...
    'FrequencySpan', {'Start and stop frequencies', 'start-and-stop-frequencies'}, ...
    'StartFrequency', 7000, 'StopFrequency', 11000, ...
    '?FrequencyResolutionMethod', {'RBW', 'rbw'}, ...
    'RBWSource', {'Property', 'property'}, 'RBW', 5, ...
    'AveragingMethod', {'Running', 'running'}, ...
    {'SpectralAverages', 'NumSpectralAverages'}, 4, ...
    {'PeakFinder.Enable', 'PeakFinder.Enabled'}, true, ...
    'PeakFinder.NumPeaks', 30, 'PeakFinder.LabelPeaks', true, ...
    '?PeakFinder.MinHeight', -10, ...
    '?ChannelMeasurements.Enable', true, ...
    '?ChannelMeasurements.Algorithm', {'Occupied BW', 'occupied-bandwidth'}, ...
    '?ChannelMeasurements.CenterFrequency', 9000, ...
    '?ChannelMeasurements.Span', 4000};
end

function finish(sys, outdir, MODEL)
audit();
expect('reset');
libraries(sys);
compiles(sys);
save_system(sys, fullfile(outdir, [MODEL '.slx']));
fprintf('saved %s\n\n', fullfile(outdir, [MODEL '.slx']));
open_system(sys);
end

function addk(sys, name, val, pos)
b = addb(sys, name, 'Constant', {'simulink/Sources/Constant', 'built-in/Constant'}, pos);
setp(b, val, {'Value'}, {'Constant value'});
end

function addgain(sys, name, k, pos)
b = addb(sys, name, 'Gain', {'simulink/Math Operations/Gain', 'built-in/Gain'}, pos);
setp(b, k, {'Gain'}, {'^Gain'});
end

function addint(sys, name, ts, pos)
% Forward Euler, gain 1: out(n) = out(n-1) + Ts*in(n-1). Integrating a
% frequency in Hz gives phase in cycles, hence the 2*pi after it.
b = addb(sys, name, 'Discrete-Time Integrator', ...
    {'simulink/Discrete/Discrete-Time Integrator', 'built-in/DiscreteIntegrator'}, pos);
setp(b, ts, {'SampleTime'}, {'Sample time'});
end

function addtrig(sys, name, fn, pos)
b = addb(sys, name, 'Trigonometric Function', ...
    {'simulink/Math Operations/Trigonometric Function', 'built-in/Trigonometry'}, pos);
setp(b, fn, {'Operator'}, {'Function'});
end

function flipblock(blk)
try %#ok<TRYNC>
    set_param(blk, 'Orientation', 'left');
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
% Load the DSP libraries up front so their block paths resolve.
for lib = {'dspsrcs4', 'dspfdesign', 'dspsnks4', 'dspstat3', 'dspmathops'}
    try %#ok<TRYNC>
        load_system(lib{1});
    end
end
end

function audit()
% Read back every value setp wrote, whichever library the block came from.
% Nothing here trusts that set_param "worked" because it did not throw: a
% later field can quietly reset an earlier one.
w = expect('get');
fprintf('\n  every parameter the script set, read back from the block\n');
bad = 0;
for i = 1:size(w, 1)
    [blk, prm, want] = w{i, :};
    got = getp(blk, {prm});
    ok = strcmpi(squash(got), squash(want));
    mark = 'ok   ';
    if ~ok, mark = 'CHECK'; bad = bad + 1; end
    fprintf('    %s %-28s %-20s %s\n', mark, short(blk), prm, got);
    if ~ok
        note(sprintf('%s: %s reads "%s", it should be %s. Open the block and set it.', ...
            short(blk), prm, got, want));
    end
end
fprintf('  %d of %d read back as set\n\n', size(w, 1) - bad, size(w, 1));
end

function libraries(sys)
% Say where every block came from. A block is DSP if its library link points
% into a DSP System Toolbox library (dsp*); built-ins have no link at all.
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
    fprintf('    %-8s %-28s %s\n', tag, short(blks{i}), oneline(ref));
end
fprintf('\n');
end

function s = short(blk)
s = regexprep(oneline(blk), '^[^/]*/', '');
end

function compiles(sys)
% The same as Ctrl+D in the editor: resolves sample times, sizes and rates, and
% throws on anything that would stop the run.
try
    set_param(sys, 'SimulationCommand', 'update');
    fprintf('  diagram update (Ctrl+D): OK, the model compiles\n\n');
catch ME
    note(sprintf('the diagram does not compile yet: %s', oneline(ME.message)));
end
end

function s = squash(s)
s = lower(regexprep(char(s), '\s+', ''));
end

% =====================================================================
% Block helpers
% =====================================================================
function addsum(sys, name, signs, pos)
b = addb(sys, name, 'Add', {'simulink/Math Operations/Add', 'built-in/Sum'}, pos);
setp(b, signs,         {'Inputs'},    {}, true);
setp(b, 'rectangular', {'IconShape'}, {}, true);
end

function addscope(sys, name, nin, pos, ttl, span)
if nargin < 6, span = 0.02; end
% DSP System Toolbox Time Scope; same viewer as the Simulink Scope.
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
cfgspec(b, {'?Title', ttl, '?ShowGrid', true, '?ShowLegend', true, ...
    'TimeSpanOverrunAction', {'Scroll', 'scroll'}, 'TimeSpan', span});
end

function addspec(sys, name, pos, pairs)
b = addb(sys, name, 'Spectrum Analyzer', ...
    {'dspsnks4/Spectrum Analyzer', 'dsp_lib/Sinks/Spectrum Analyzer', 'built-in/SpectrumAnalyzer'}, pos);
cfgspec(b, pairs);
end

function pairs = specpairs(ttl, f1, f2, rbw, npeaks, minh)
% One-sided power spectrum over f1..f2 Hz at a fixed RBW, peak finder on.
pairs = { ...
    'Title', ttl, 'ShowLegend', true, ...
    'SpectrumType', {'Power', 'power'}, 'SpectrumUnits', 'dBm', ...
    'PlotAsTwoSidedSpectrum', false, ...
    'FrequencySpan', {'Start and stop frequencies', 'start-and-stop-frequencies'}, ...
    'StartFrequency', f1, 'StopFrequency', f2, ...
    '?FrequencyResolutionMethod', {'RBW', 'rbw'}, ...
    'RBWSource', {'Property', 'property'}, 'RBW', rbw, ...
    'AveragingMethod', {'Running', 'running'}, ...
    {'SpectralAverages', 'NumSpectralAverages'}, 4, ...
    {'PeakFinder.Enable', 'PeakFinder.Enabled'}, true, ...
    'PeakFinder.NumPeaks', npeaks, 'PeakFinder.LabelPeaks', true, ...
    '?PeakFinder.MinHeight', minh};
end

function addarea(sys, label, pos)
% The shaded boxes are Simulink areas (annotations), not subsystems: purely
% visual. If this release will not make one from a script, nothing is lost.
try
    a = Simulink.Annotation(sys, label);
    a.AnnotationType = 'area_annotation';
    a.Position = pos;
    return
catch
end
try
    add_block('built-in/Area', [sys '/' label], 'Position', pos);
catch
    fprintf('  (cosmetic) the "%s" shaded area was not drawn\n', label);
end
end

function hidename(blk)
if isempty(blk), return, end
try %#ok<TRYNC>
    set_param(blk, 'ShowName', 'off');
end
end

% =====================================================================
% Plumbing
% =====================================================================
function sys = newmodel(name, outdir, stoptime, ts, solver)
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
p = '';
words = strsplit(strtrim(libname));
pat = ['^' strjoin(words, '[ \n]+') '$'];
tops = {'simulink', 'dsp_lib', 'commlib'};
for k = 1:numel(tops)
    try
        load_system(tops{k});
        r = find_system(tops{k}, 'MatchFilter', @Simulink.match.allVariants, ...
            'FollowLinks', 'on', 'LookUnderMasks', 'all', 'RegExp', 'on', 'Name', pat);
        if ~isempty(r), p = r{1}; return, end
    catch
    end
end
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
try
    mp = get_param(blk, 'MaskPrompts');
    mn = get_param(blk, 'MaskNames');
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
catch
end
if ~quiet
    label = names;
    if isempty(label), label = prompts; end
    if isempty(why)
        why = sprintf('no such dialog field; it has: %s', strjoin(known(:)', ', '));
    end
    note(sprintf('%s: "%s" = %s not set (%s)', blk, label{1}, val, why));
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
% Push display settings into a Scope or Spectrum Analyzer ScopeConfiguration.
% A name or a value may be a cell of alternatives; a leading '?' means optional.
if isempty(blk), return, end
try
    cfg = get_param(blk, 'ScopeConfiguration');
catch
    note(sprintf('%s: no ScopeConfiguration, set span / RBW / peak finder from the toolstrip', blk));
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
        note(sprintf('%s: display option "%s" not set (%s)', blk, prop{1}, why));
    end
end
end

function conn(sys, src, dst, signame)
try
    h = add_line(sys, src, dst, 'autorouting', 'on');
    if nargin > 3 && ~isempty(signame)
        try %#ok<TRYNC>
            set_param(h, 'Name', signame);
        end
    end
catch ME
    note(sprintf('connect %s -> %s by hand (%s)', src, dst, oneline(ME.message)));
end
end

function report()
m = note('get');
if isempty(m)
    fprintf('nothing outstanding. The model is ready to run.\n');
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
% Every value setp wrote, so audit can read each one back. A later write to the
% same field replaces the earlier one.
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
