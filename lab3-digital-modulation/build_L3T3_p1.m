function build_L3T3_p1(mode)
%BUILD_L3T3_P1  ECSE 308 L3T3 Part 1: baseband digital transmission.
%
%   build_L3T3_p1          builds three models under models/ and opens them
%   build_L3T3_p1 sweep    question 4: BER at Eb/No = 0, 2, 4, 6, 8, 10 dB,
%                          table + plot against theory (needs the build first)
%
% The three models, block for block as the handout draws them:
%
%   L3T3_ADC_DAC        pages 4-5, questions 1 and 2. A 500 Hz sine of
%                       amplitude 2 is sampled at 8 kHz (Product with a pulse
%                       train, and Sample and Hold), quantized to 8 levels
%                       (3 bits), decoded back and smoothed by a 20th-order
%                       Butterworth lowpass at 500 Hz.
%   L3T3_ADC_DAC_2bit   the same with question 3's second setup: boundaries
%                       -2:2, codebook -1.5:1:1.5, so 4 levels (2 bits).
%   L3T3_Baseband       pages 7-8, question 4. Bits 0/1 -> +-5 V -> AWGN ->
%                       sampled mid-bit -> Sign -> back to +-5 -> Error Rate.
%
% Settings the handout leaves open:
%
%   * ADC/DAC: no sample time for the sine and no stop time. The sine is
%     sampled every 5e-7 s (250 steps per 0.125 ms pulse period, so each
%     pulse edge lands exactly on a step), fixed-step ode4 at 5e-7 s because
%     the Analog Filter Design block is continuous-time, stop 0.2 s.
%     If the time-based Pulse Generator does not compile against Sample and
%     Hold, the script switches it to the identical sample-based pulse
%     (250 samples per period, 125 high) and says so.
%   * Scope (Filtered) also shows the source sine (input 2), and Scope (PAM)
%     also shows the transmitted signal (input 2), so the screenshot shows
%     input and output together. Nothing else is added.
%   * Baseband: stop time inf; the Error Rate Calculation ends the run at 200
%     errors or 1e6 bits, as page 8 sets it. Eb/No starts at 4 dB, so the
%     first run finishes in seconds.
%   * Spectra two-sided, dBm, behind the 1e-5 s Rate Transitions of page 5,
%     so they show -50 to +50 kHz.
%
% Ends each model by reading every parameter back (ok / CHECK), listing which
% library each block came from, and compiling it (Ctrl+D), before it saves.

if nargin < 1, mode = 'build'; end
note('reset');
checkproducts();
outdir = fullfile(pwd, 'models');
if ~exist(outdir, 'dir'), mkdir(outdir); end

switch lower(mode)
    case 'build'
        buildadc('L3T3_ADC_DAC',      '-2:0.5:2', '[-1.75:0.5:1.75]', outdir);
        buildadc('L3T3_ADC_DAC_2bit', '[-2:2]',   '[-1.5:1:1.5]',     outdir);
        buildbb('L3T3_Baseband', outdir);
        open_system('L3T3_ADC_DAC');
    case 'sweep'
        sweepbb(outdir);
    otherwise
        note(sprintf('unknown mode "%s": use build_L3T3_p1 or build_L3T3_p1 sweep', mode));
end
report();
end

% =====================================================================
% Model 1: ADC/DAC (pages 4-5)
% =====================================================================
function buildadc(name, bounds, codebook, outdir)
TS = '5e-7';
RT = '1e-5';
STOP = '0.2';
expect('reset');
sys = newmodel(name, outdir, STOP, TS, 'ode4');

addsineT(sys, 'Sine Wave', '2', '500*2*pi', TS, [110 640 165 690]);

addscope(sys, 'Scope (Source)', 1, [310 270 360 325], 'Source: 500 Hz sine, amplitude 2', 0.004, false);
addrt(sys, 'RT (Source)', RT, [295 420 360 485]);
hidename([sys '/RT (Source)']);
addspec(sys, 'Spectrum (Source)', [460 255 535 350], specp('Spectrum (Source)', [-2000 2000], 50, 2, 0, [-40 40]));
conn(sys, 'Sine Wave/1', 'Scope (Source)/1');
conn(sys, 'Sine Wave/1', 'RT (Source)/1');
conn(sys, 'RT (Source)/1', 'Spectrum (Source)/1');

% Natural sampling: sine x 8 kHz pulse train, 50% duty cycle.
addpulse(sys, 'Pulse Generator', 'Time based', '0.001/8', '50', '0', '', [465 450 520 500]);
addprod(sys, 'Product', [600 528 645 578]);
conn(sys, 'Pulse Generator/1', 'Product/1');
conn(sys, 'Sine Wave/1', 'Product/2');
addscope(sys, 'Scope (Sample)', 1, [865 532 915 585], 'Sine x pulse train (natural sampling)', 0.004, false);
addrt(sys, 'RT (Sample)', RT, [718 405 783 477]);
hidename([sys '/RT (Sample)']);
addspec(sys, 'Spectrum (Sample)', [795 255 873 350], specp('Spectrum (Sample)', [], 50, 16, 5, [-20 40]));
conn(sys, 'Product/1', 'Scope (Sample)/1');
conn(sys, 'Product/1', 'RT (Sample)/1');
conn(sys, 'RT (Sample)/1', 'Spectrum (Sample)/1');

% Sample and Hold, triggered by the same pulse train.
addsh(sys, 'Sample and Hold', [447 618 535 700]);
conn(sys, 'Sine Wave/1', 'Sample and Hold/1');
connany(sys, 'Pulse Generator/1', {'Sample and Hold/Trigger', 'Sample and Hold/2'});

% Quantizer: encoder gives the level number I and the level value Q(U).
e = addb(sys, 'Scalar Quantizer Encoder', 'Scalar Quantizer Encoder', ...
    {'dspquant2/Scalar Quantizer Encoder', 'dsp_lib/Quantizers/Scalar Quantizer Encoder'}, [660 608 795 705]);
setopt(e, 'dialog', {'paramSrc', 'Source'}, {'Source of quantizer'}, true);
setopt(e, '^Bounded$', {'partType', 'Partitioning'}, {'Partitioning'});
setp(e, bounds,   {'BBoundary', 'BoundaryPoints'}, {'Boundary points'});
% Codebook before "Output codeword": ticking it checks the codebook length
% against the boundaries at once.
setp(e, codebook, {'codebook', 'Codebook'},        {'^Codebook'});
setp(e, 'on',     {'outQU', 'OutputQU'},           {'codeword'});
conn(sys, 'Sample and Hold/1', 'Scalar Quantizer Encoder/1');

d = addb(sys, 'Scalar Quantizer Decoder', 'Scalar Quantizer Decoder', ...
    {'dspquant2/Scalar Quantizer Decoder', 'dsp_lib/Quantizers/Scalar Quantizer Decoder'}, [870 858 1028 960]);
setopt(d, 'dialog', {'Source', 'src'}, {'Source of codebook'}, true);
setp(d, codebook, {'Codebook', 'codebook', 'CodebookValues'}, {'^Codebook'});
conn(sys, 'Scalar Quantizer Encoder/1', 'Scalar Quantizer Decoder/1');

addscope(sys, 'Scope (S//H)', 2, [638 855 686 908], 'S/H output (1) and the sine (2)', 0.004, false);
conn(sys, 'Sample and Hold/1', 'Scope (S//H)/1');
conn(sys, 'Sine Wave/1', 'Scope (S//H)/2');

addscope(sys, 'Scope (ADC)', 3, [1155 660 1218 735], ...
    'Codeword Q(U) (1), S/H output (2), decoder output (3)', 0.004, false);
conn(sys, 'Scalar Quantizer Encoder/2', 'Scope (ADC)/1');
conn(sys, 'Sample and Hold/1', 'Scope (ADC)/2');
conn(sys, 'Scalar Quantizer Decoder/1', 'Scope (ADC)/3');

addbutter(sys, 'Analog Filter Design', 'Lowpass', {'500*2*pi'}, '20', [1133 858 1238 960]);
conn(sys, 'Scalar Quantizer Decoder/1', 'Analog Filter Design/1');
addscope(sys, 'Scope (Filtered)', 2, [1313 885 1358 930], 'Recovered (1) and source sine (2)', 0.004, false);
conn(sys, 'Analog Filter Design/1', 'Scope (Filtered)/1');
conn(sys, 'Sine Wave/1', 'Scope (Filtered)/2');

set_param(sys, 'Description', sprintf([ ...
    'ECSE 308 L3T3 Part 1: ADC/DAC. Boundaries %s, codebook %s.\n' ...
    'Fixed-step ode4 at %s s, stop %s s, spectra behind %s s Rate Transitions.'], ...
    bounds, codebook, TS, STOP, RT));

audit();
libraries(sys);
[ok, msg] = tryupdate(sys);
if ~ok
    % Same pulse train, counted in solver steps instead of seconds.
    fprintf('  first compile failed (%s)\n  trying the Pulse Generator sample based instead\n', msg);
    p = [sys '/Pulse Generator'];
    setp(p, 'Sample based', {'PulseType'},  {'Pulse type'});
    setp(p, '250',          {'Period'},     {'Period'});
    setp(p, '125',          {'PulseWidth'}, {'Pulse Width'});
    setp(p, '0',            {'PhaseDelay'}, {'Phase delay'});
    setp(p, TS,             {'SampleTime'}, {'Sample time'});
    [ok, msg2] = tryupdate(sys);
    if ok
        note(sprintf(['%s: the time-based Pulse Generator would not compile, so it is now sample ' ...
            'based: 250 steps of 5e-7 s = 0.125 ms period, 125 steps high. The same 8 kHz, ' ...
            '50%% pulse train. Nothing to do. (The first error was: %s)'], sys, msg));
    else
        note(sprintf('%s does not compile: %s', sys, msg2));
    end
end
if ok
    fprintf('  diagram update (Ctrl+D): OK, %s compiles\n\n', sys);
end
savemodel(sys, outdir);
end

% =====================================================================
% Model 2: baseband transmission over AWGN (pages 7-8)
% =====================================================================
function buildbb(name, outdir)
expect('reset');
sys = newmodel(name, outdir, 'inf', 'auto', 'FixedStepDiscrete');

% +-5 V bits: (b - 0.5) x 10.
addbern(sys, 'Bernoulli Binary Generator (Source)', '1e-3', '1', '', [38 375 180 450]);
addconst(sys, 'Constant (DC Bias)', '0.5', [207 495 270 540]);
addsum(sys, 'Add', '+-', [333 398 387 458]);
addgain(sys, 'Gain', '10', [432 405 488 450]);
conn(sys, 'Bernoulli Binary Generator (Source)/1', 'Add/1');
conn(sys, 'Constant (DC Bias)/1', 'Add/2');
conn(sys, 'Add/1', 'Gain/1');

addawgn(sys, 'AWGN Channel', 'Eb/No', '4', '1', '25', '1e-3', [600 378 773 488]);
conn(sys, 'Gain/1', 'AWGN Channel/1');

% Sample once per bit, in the middle: the pulse is 0 for the first half of
% each 1 ms bit and rises at 0.5 ms.
addpulse(sys, 'Pulse Generator', 'Sample based', '2', '1', '1', '0.5e-3', [848 222 926 278]);
addsh(sys, 'Sample and Hold', [851 393 941 477]);
conn(sys, 'AWGN Channel/1', 'Sample and Hold/1');
connany(sys, 'Pulse Generator/1', {'Sample and Hold/Trigger', 'Sample and Hold/2'});

% Decide: Sign gives -1 / 0 / +1, the table turns that back into -5 / +5.
addsign(sys, 'Sign', [1046 408 1103 458]);
addlut(sys, 'Lookup Table', '[-5,-5,5]', '[-1,0,1]', [1152 375 1275 495]);
conn(sys, 'Sample and Hold/1', 'Sign/1');
conn(sys, 'Sign/1', 'Lookup Table/1');

adderr(sys, 'Error Rate Calculation', '1', [600 735 735 833]);
adddisp(sys, 'Display (BER)', [807 705 938 818]);
conn(sys, 'Gain/1', 'Error Rate Calculation/1');
conn(sys, 'Lookup Table/1', 'Error Rate Calculation/2');
conn(sys, 'Error Rate Calculation/1', 'Display (BER)/1');

SPAN = 0.02;   % 20 bits on every scope
addscope(sys, 'Scope (Tx)', 1, [575 552 628 605], 'Transmitted +-5 V', SPAN, false);
addscope(sys, 'Scope (Rx)', 1, [870 533 923 585], 'Received (with noise)', SPAN, false);
addscope(sys, 'Scope (Pulse)', 1, [968 293 1020 345], 'Sampling pulse', SPAN, false);
addscope(sys, 'Scope (S//H)', 1, [1050 533 1103 585], 'Sampled and held', SPAN, false);
addscope(sys, 'Scope (PAM)', 2, [1380 405 1433 450], 'Decided bits (1) and transmitted (2)', SPAN, true);
conn(sys, 'Gain/1', 'Scope (Tx)/1');
conn(sys, 'AWGN Channel/1', 'Scope (Rx)/1');
conn(sys, 'Pulse Generator/1', 'Scope (Pulse)/1');
conn(sys, 'Sample and Hold/1', 'Scope (S//H)/1');
conn(sys, 'Lookup Table/1', 'Scope (PAM)/1');
conn(sys, 'Gain/1', 'Scope (PAM)/2');

set_param(sys, 'Description', sprintf([ ...
    'ECSE 308 L3T3 Part 1: +-5 V bits at 1 kb/s over AWGN, sampled mid-bit.\n' ...
    'Stops at 200 errors or 1e6 bits. Display: BER, errors, bits compared.']));

audit();
libraries(sys);
compiles(sys);
savemodel(sys, outdir);
end

% =====================================================================
% Question 4: the BER curve
% =====================================================================
function sweepbb(outdir)
src = fullfile(outdir, 'L3T3_Baseband.slx');
if ~exist(src, 'file')
    note('models/L3T3_Baseband.slx does not exist yet. Run build_L3T3_p1 first.');
    return
end
[tmp, f] = sweepcopy(src);
cleaner = onCleanup(@() dropcopy(tmp, f));
awgn = [tmp '/AWGN Channel'];
prm = pname(awgn, {'EbNo', 'EbNodB'}, {'Eb/No'});

x = 0:2:10;
rows = zeros(numel(x), 6);
fprintf('\n  Eb/No(dB)   BER sim      errors    bits        Q(sqrt(2EbNo))  Q(sqrt(EbNo))\n');
for i = 1:numel(x)
    set_param(awgn, prm, num2str(x(i)));
    try
        v = runber(tmp);
    catch ME
        note(sprintf('Eb/No = %g dB: the run failed (%s)', x(i), errtext(ME)));
        continue
    end
    g = 10^(x(i)/10);
    th  = 0.5 * erfc(sqrt(g));        % Q(sqrt(2 Eb/No)), the textbook result
    th2 = 0.5 * erfc(sqrt(g/2));      % Q(sqrt(Eb/No)), the same with twice the noise
    rows(i, :) = [x(i) v(1) v(2) v(3) th th2];
    fprintf('  %6g      %-11.4g  %-8d  %-10d  %-14.4g  %.4g\n', rows(i, 1), rows(i, 2), ...
        round(rows(i, 3)), round(rows(i, 4)), rows(i, 5), rows(i, 6));
end

fig = figure('Name', 'L3T3 Part 1 Q4: BER vs Eb/No', 'Color', 'w');
try, theme(fig, 'light'); end   % MATLAB Online's dark theme otherwise blackens the axes
xt = linspace(0, 10, 200);
semilogy(xt, 0.5 * erfc(sqrt(10.^(xt/10))), 'k-', 'LineWidth', 1.2);
hold on
okp = rows(:, 2) > 0;
semilogy(rows(okp, 1), rows(okp, 2), 'ro', 'MarkerSize', 8, 'LineWidth', 1.5);
grid on
xlabel('E_b/N_0 (dB)');
ylabel('Bit error rate');
title('Baseband \pm5 V over AWGN: BER vs E_b/N_0');
legend('Theory Q(\surd(2E_b/N_0))', 'Simulink', 'Location', 'southwest');
saveplot(fig, 'L3T3_p1_ber', rows, 'EbNo_dB,BER_sim,errors,bits,Q_sqrt_2EbNo,Q_sqrt_EbNo', outdir);
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
