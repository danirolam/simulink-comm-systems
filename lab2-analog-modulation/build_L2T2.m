function build_L2T2
%BUILD_L2T2  ECSE 308 L2T2 Part 1, section I: the DSB-LC AM system, one model.
%
%   build_L2T2      builds models/L2T2_DSB_LC.slx under the current folder
%
% Draws the handout's page 4 circuit block for block and wire for wire, with
% every parameter from page 5 typed in:
%
%   Source      Sine Wave 1, 2, 3 -> Add
%   Modulation  (source + Constant 6) x Carrier  = (6 + m(t)) cos(wc t)
%   Channel     AWGN Channel, variance 1e-2
%   Receiver    Analog Filter Design (Butterworth bandpass, order 8,
%               14.3 to 15.8 kHz) -> Rate Transition (2e-5)
%   Envelope    u^2 -> x2 -> FIR Decimation [1 1] by 2 ->
%   Detector    Discrete FIR firpm(20, ...) -> signed sqrt
%
% plus the five Scopes, the five Spectrum Analyzers and the small Rate
% Transition in front of each Spectrum Analyzer, laid out where the handout
% draws them.
%
% Every block that has a DSP System Toolbox version is taken from the DSP
% library: Sine Wave, Constant (DSP Constant), Discrete FIR Filter, FIR
% Decimation, Analog Filter Design, Spectrum Analyzer, and Time Scope for the
% Scopes. The rest have no DSP version and come from where they live: AWGN
% Channel from Communications Toolbox; Add, Product, Gain, Math Function, Sqrt
% and Rate Transition from Simulink. The run ends with a table naming the
% library every block actually came from.
%
% The DSP Sine Wave takes its frequency in Hz, the handout gives rad/s, so the
% handout's number is entered divided by 2*pi and left visible in the dialog:
% 1000*pi/(2*pi) is 500 Hz. It is the same sinusoid, sin(2*pi*f*t + phase).
%
% The handout does not give three things, so they are chosen here:
%
%   * Sample time of the four sine sources: 1e-6 s (1 MHz). The carrier is
%     15 kHz, so this is about 67 samples per carrier cycle, and 1e-6 divides
%     the handout's 2e-5 exactly, so the Rate Transition is a clean 20:1.
%   * Solver: fixed-step ode4 at 1e-6. The Analog Filter Design block is a
%     continuous-time filter, so the model needs a continuous solver.
%   * The Rate Transitions in front of the Spectrum Analyzers: 1e-4 for the
%     source (it has nothing above 600 Hz, so nothing aliases), 1e-6 for Mod,
%     Rx and BPF (keeps the full-rate noise honest), inherited for ED.
%
% It ends by compiling the diagram (the same thing as Ctrl+D) and reading every
% handout parameter back out of the blocks, so a wrong or unset value shows up
% in the Command Window before you press Run.
%
% Needs Simulink, DSP System Toolbox, Communications Toolbox and Signal
% Processing Toolbox. All four are on the McGill campus licence.

MODEL = 'L2T2_DSB_LC';
TS    = '1e-6';
STOP  = '0.5';

note('reset');
checkproducts();

outdir = fullfile(pwd, 'models');
if ~exist(outdir, 'dir'), mkdir(outdir); end
sys = newmodel(MODEL, outdir, STOP, TS);

% ---- the three shaded areas, drawn first so they sit behind the blocks --
addarea(sys, 'Source',            [15 490 290 898]);
addarea(sys, 'Modulation',        [350 628 808 992]);
addarea(sys, 'Envelope Detector', [929 773 1620 954]);

% ---- Source ------------------------------------------------------------
addsine(sys, 'Sine Wave 1', '1',   '1000*pi', '0', TS, [45 553 107 613]);
addsine(sys, 'Sine Wave 2', '3',   '600*pi',  '0', TS, [45 675 107 737]);
addsine(sys, 'Sine Wave 3', '1.5', '1200*pi', '0', TS, [45 808 107 868]);
addsum(sys, 'Add', '+++', [198 673 258 738]);
conn(sys, 'Sine Wave 1/1', 'Add/1');
conn(sys, 'Sine Wave 2/1', 'Add/2');
conn(sys, 'Sine Wave 3/1', 'Add/3');

addscope(sys, 'Scope (Source)', 1, [380 162 442 228], 'Source m(t)');
addrt(sys, 'RT (Source)', '1e-4', [450 338 535 420]);
addspec(sys, 'Spectrum (Source)', [634 142 726 248], ...
    specpairs('Source', 0, 1000, 5, 4, 0));
conn(sys, 'Add/1', 'Scope (Source)/1', 'm');
conn(sys, 'Add/1', 'RT (Source)/1');
conn(sys, 'RT (Source)/1', 'Spectrum (Source)/1');

% ---- Modulation --------------------------------------------------------
addsum(sys, 'Add (DC Bias)', '++', [522 689 584 753]);
hidename([sys '/Add (DC Bias)']);
addconst(sys, 'Constant (DC Bias)', '6', TS, [380 767 442 827]);
addsine(sys, 'Carrier (Mod)', '1', '30000*pi', 'pi/2', TS, [380 869 442 929]);
p = addb(sys, 'Product', 'Product', ...
    {'simulink/Math Operations/Product', 'built-in/Product'}, [715 710 777 772]);
setp(p, '2', {'Inputs'}, {'Number of inputs'}, true);

conn(sys, 'Add/1', 'Add (DC Bias)/1');
conn(sys, 'Constant (DC Bias)/1', 'Add (DC Bias)/2');
conn(sys, 'Add (DC Bias)/1', 'Product/1', 'A0 + m');
conn(sys, 'Carrier (Mod)/1', 'Product/2', 'carrier');

addscope(sys, 'Scope (Mod)', 2, [960 389 1022 459], 'AM signal and its envelope');
addrt(sys, 'RT (Mod)', TS, [785 236 870 318]);
addspec(sys, 'Spectrum (Mod)', [960 142 1052 248], ...
    specpairs('Mod', 13000, 17000, 20, 7, 0));
conn(sys, 'Product/1', 'Scope (Mod)/1', 'am');
conn(sys, 'Add (DC Bias)/1', 'Scope (Mod)/2');
conn(sys, 'Product/1', 'RT (Mod)/1');
conn(sys, 'RT (Mod)/1', 'Spectrum (Mod)/1');

% ---- Channel -----------------------------------------------------------
a = addb(sys, 'AWGN Channel', 'AWGN Channel', ...
    {'commchan3/AWGN Channel', 'commlib/Channels/AWGN Channel'}, [929 555 1123 673]);
setp(a, 'randseed',           {'seed'},      {'Initial seed'});
setp(a, 'Variance from mask', {'noiseMode'}, {'^Mode'});
setp(a, '1e-2',               {'variance'},  {'^Variance'});
conn(sys, 'Product/1', 'AWGN Channel/1');

addscope(sys, 'Scope (Rx)', 1, [1265 397 1327 462], 'Received (AM + noise)');
addrt(sys, 'RT (Rx)', TS, [1121 256 1206 338]);
addspec(sys, 'Spectrum (Rx)', [1224 142 1316 248], ...
    specpairs('Rx', 0, 25000, 20, 7, 0));
conn(sys, 'AWGN Channel/1', 'Scope (Rx)/1', 'rx');
conn(sys, 'AWGN Channel/1', 'RT (Rx)/1');
conn(sys, 'RT (Rx)/1', 'Spectrum (Rx)/1');

% ---- Receiver bandpass filter ------------------------------------------
BPF = 'Analog Filter Design (BPF)';
f = addb(sys, BPF, 'Analog Filter Design', { ...
    'dsparch4/Analog Filter Design', ...
    'dsp_lib/Filtering/Filter Designs/Analog Filter Design', ...
    'dsp_lib/Filtering/Filter Implementations/Analog Filter Design'}, [1235 557 1366 670]);
% Filter type first: the passband-edge fields only exist once it is Bandpass.
setp(f, 'Butterworth',  {'method'},   {'Design method'});
setp(f, 'Bandpass',     {'filttype'}, {'Filter type'});
setp(f, '8',            {'N'},        {'Filter order'});
setp(f, '14300*2*pi',   {'Wlo'},      {'Lower passband edge'});
setp(f, '15800*2*pi',   {'Whi'},      {'Upper passband edge'});
conn(sys, 'AWGN Channel/1', [BPF '/1']);

addscope(sys, 'Scope (BPF)', 1, [1529 397 1591 462], 'After the bandpass filter');
addrt(sys, 'RT (BPF)', TS, [1385 256 1470 338]);
addspec(sys, 'Spectrum (BPF)', [1488 142 1580 248], ...
    specpairs('BPF', 0, 25000, 20, 7, 0));
conn(sys, [BPF '/1'], 'Scope (BPF)/1', 'bpf');
conn(sys, [BPF '/1'], 'RT (BPF)/1');
conn(sys, 'RT (BPF)/1', 'Spectrum (BPF)/1');

r = addb(sys, 'Rate Transition', 'Rate Transition', ...
    {'simulink/Signal Attributes/Rate Transition', 'built-in/RateTransition'}, [1519 571 1600 655]);
setp(r, '2e-5', {'OutPortSampleTime'}, {'Output port sample time'});
conn(sys, [BPF '/1'], 'Rate Transition/1');

% ---- Envelope Detector -------------------------------------------------
m = addb(sys, 'Math Function', 'Math Function', ...
    {'simulink/Math Operations/Math Function', 'built-in/Math'}, [960 838 1022 898]);
setp(m, 'square', {'Operator'}, {'Function'});

g = addb(sys, 'Gain', 'Gain', {'simulink/Math Operations/Gain', 'built-in/Gain'}, [1060 838 1122 898]);
setp(g, '2', {'Gain'}, {'^Gain'});
hidename(g);

d = addb(sys, 'FIR Decimation', 'FIR Decimation', { ...
    'dspmlti4/FIR Decimation', ...
    'dsp_lib/Signal Operations/Multirate Filters/FIR Decimation', ...
    'dsp_lib/Filtering/Multirate Filters/FIR Decimation'}, [1163 834 1255 902]);
setp(d, '[1 1]', {'h', 'Coefficients'}, {'FIR filter coefficients', 'Coefficients'});
setp(d, '2',     {'D'},                 {'Decimation factor'});
% The input is one sample at a time, so the block has to be allowed to change
% rate (2e-5 in, 4e-5 out). Its single-rate mode wants frames of D samples.
setp(d, 'Allow multirate processing', {'framing', 'RateOptions'}, {'Rate options'}, true);

x = addb(sys, 'Discrete FIR Filter', 'Discrete FIR Filter', { ...
    'dsparch4/Discrete FIR Filter', ...
    'dsp_lib/Filtering/Filter Implementations/Discrete FIR Filter', ...
    'simulink/Discrete/Discrete FIR Filter'}, [1305 814 1478 924]);
setp(x, 'firpm(20, [0 0.03 0.1 1], [1 1 0 0])', {'Coefficients'}, {'Coefficients'});

s = addb(sys, 'Sqrt', 'Sqrt', {'simulink/Math Operations/Sqrt', 'built-in/Sqrt'}, [1530 838 1590 898]);
setp(s, 'signedSqrt', {'Operator'}, {'Function'});

conn(sys, 'Rate Transition/1', 'Math Function/1');
conn(sys, 'Math Function/1', 'Gain/1');
conn(sys, 'Gain/1', 'FIR Decimation/1');
conn(sys, 'FIR Decimation/1', 'Discrete FIR Filter/1');
conn(sys, 'Discrete FIR Filter/1', 'Sqrt/1');

addscope(sys, 'Scope (ED)', 2, [1763 391 1825 457], 'Recovered vs source');
addrt(sys, 'RT (ED)', '-1', [1639 256 1724 338]);
addspec(sys, 'Spectrum (ED)', [1742 142 1834 248], ...
    specpairs('ED', 0, 1000, 5, 4, 0));
conn(sys, 'Sqrt/1', 'Scope (ED)/1', 'recovered');
conn(sys, 'Add/1', 'Scope (ED)/2');
conn(sys, 'Sqrt/1', 'RT (ED)/1');
conn(sys, 'RT (ED)/1', 'Spectrum (ED)/1');

set_param(sys, 'Description', sprintf([ ...
    'ECSE 308 L2T2 Part 1, section I: DSB-LC AM.\n' ...
    'Sources sampled at %s s, fixed-step ode4 at %s s, stop %s s.\n' ...
    'Step 6: change Constant (DC Bias) and Run again.'], TS, TS, STOP));

% ---- read it back, compile it, save it ---------------------------------
audit();
libraries(sys);
compiles(sys);
save_system(sys, fullfile(outdir, [MODEL '.slx']));
fprintf('saved %s\n', fullfile(outdir, [MODEL '.slx']));
open_system(sys);
report();
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
for lib = {'dspsrcs4', 'dsparch4', 'dspmlti4', 'dspsnks4'}
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
function addsine(sys, name, amp, w, phase, ts, pos)
% DSP System Toolbox Sine Wave, discrete, one sample per frame. It takes Hz, the
% handout gives rad/s, so w goes in as w/(2*pi).
b = addb(sys, name, 'Sine Wave', {'dspsrcs4/Sine Wave', 'dsp_lib/Sources/Sine Wave'}, pos, true);
if ~isempty(b)
    setp(b, 'Discrete',          {'SampleMode'},      {'Sample mode'});
    setp(b, 'Real',              {'OutComplex'},      {'Output complexity'}, true);
    setp(b, amp,                 {'Amplitude'},       {'^Amplitude'});
    setp(b, [w '/(2*pi)'],       {'Frequency'},       {'^Frequency'});
    setp(b, phase,               {'Phase'},           {'^Phase'});
    setp(b, 'Trigonometric fcn', {'CompMethod'},      {'Computation method'}, true);
    setp(b, ts,                  {'SampleTime'},      {'^Sample time'});
    setp(b, '1',                 {'SamplesPerFrame'}, {'Samples per frame'});
    return
end
note(sprintf(['%s: the DSP Sine Wave is not in this session, so the Simulink ' ...
    'one is used, with the handout''s rad/s values as written'], name));
b = addb(sys, name, 'Sine Wave', {'simulink/Sources/Sine Wave', 'built-in/Sin'}, pos);
if isempty(b), return, end
setp(b, 'Time based',          {'SineType'},   {'Sine type'});
setp(b, 'Use simulation time', {'TimeSource'}, {'^Time'}, true);
setp(b, amp,   {'Amplitude'},  {'Amplitude'});
setp(b, '0',   {'Bias'},       {}, true);
setp(b, w,     {'Frequency'},  {'Frequency'});
setp(b, phase, {'Phase'},      {'Phase'});
setp(b, ts,    {'SampleTime'}, {'Sample time'});
end

function addconst(sys, name, val, ts, pos)
% DSP Constant, discrete at the source rate so the whole modulator runs at one
% rate. Falls back to the Simulink Constant if this release has dropped it.
b = addb(sys, name, 'DSP Constant', {'dspsrcs4/DSP Constant', 'dsp_lib/Sources/DSP Constant'}, pos, true);
if ~isempty(b)
    setp(b, val,        {'Value'},      {'Constant value'});
    setp(b, 'Discrete', {'SampleMode'}, {'Sample mode'}, true);
    setp(b, ts,         {'SampTime', 'SampleTime'}, {'^Sample time'}, true);
    return
end
note(sprintf('%s: no DSP Constant in this session, the Simulink Constant is used', name));
b = addb(sys, name, 'Constant', {'simulink/Sources/Constant', 'built-in/Constant'}, pos);
setp(b, val, {'Value'}, {'Constant value'});
end

function addsum(sys, name, signs, pos)
b = addb(sys, name, 'Add', {'simulink/Math Operations/Add', 'built-in/Sum'}, pos);
setp(b, signs,         {'Inputs'},    {}, true);
setp(b, 'rectangular', {'IconShape'}, {}, true);
end

function addrt(sys, name, ts, pos)
% The small Rate Transition in front of each Spectrum Analyzer. Unnamed on the
% handout's canvas, so the name is hidden here too.
b = addb(sys, name, 'Rate Transition', ...
    {'simulink/Signal Attributes/Rate Transition', 'built-in/RateTransition'}, pos);
setp(b, ts, {'OutPortSampleTime'}, {'Output port sample time'});
hidename(b);
end

function addscope(sys, name, nin, pos, ttl)
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
% About two periods of the 100 Hz source pattern.
cfgspec(b, {'?Title', ttl, '?ShowGrid', true, '?ShowLegend', true, ...
    'TimeSpanOverrunAction', {'Scroll', 'scroll'}, 'TimeSpan', 0.02});
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
function sys = newmodel(name, outdir, stoptime, ts)
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
% ode4 rather than a discrete solver: the Analog Filter Design block has
% continuous states.
set_param(sys, 'SolverType', 'Fixed-step', 'Solver', 'ode4', ...
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
