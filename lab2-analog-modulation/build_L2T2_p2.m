function build_L2T2_p2
%BUILD_L2T2_P2  ECSE 308 L2T2 Part 2: the FM system, plus a linearity check.
%
%   build_L2T2_p2   builds two models under models/ in the current folder:
%
%   L2T2_FM            the handout's page 11 circuit, block for block
%   L2T2_FM_linearity  for step 2: FM of (m1 + m2) next to FM(m1) + FM(m2)
%
% L2T2_FM, left to right:
%
%   FM Modulation  Sine Wave (1 kHz) -> Gain 3000 -> + Constant 9000
%                  -> Discrete-Time Integrator -> Gain 2*pi -> cos
%                  so the carrier's frequency is 9000 + 3000*m(t) Hz
%   Demodulator    Product -> Saturation -> Digital Filter Design (lowpass)
%                  with a VCO in the feedback path built like the modulator
%                  (Gain 3000 -> + 9000 -> integrator -> 2*pi -> sin).
%                  This is a phase-locked loop: the filter output is whatever
%                  it takes to make the VCO follow the incoming frequency, and
%                  that is the recovered message.
%
% Every parameter from page 12 is typed in. Three things are not:
%
%   * The Digital Filter Design block keeps its filter in an internal object
%     that only its own dialog can set (Lab 1 found the same). The script
%     places the real block and prints the exact dialog entries. Until they
%     are entered it holds MATLAB's default design, which filters nothing here.
%   * The handout does not give Saturation limits for Part 2. The Simulink
%     defaults, +0.5 and -0.5, are set explicitly; they match Part 3's.
%   * The Sine Wave is the DSP System Toolbox one, which takes Hz. The
%     handout's Simulink setting, 1000 samples per period at 1e-6 s, is a
%     1 kHz sine, entered as 1/(1000*1e-6). Change the Frequency field to change
%     the modulating frequency (step 4).
%
% The Constant blocks are Simulink's. The DSP Constant now lives in DSP System
% Toolbox's obsolete-blocks library (dspobslib), which is where the Part 1
% build found it.
%
% Needs Simulink, DSP System Toolbox and Signal Processing Toolbox.

TS   = '1e-6';
STOP = '0.2';

note('reset');
checkproducts();
outdir = fullfile(pwd, 'models');
if ~exist(outdir, 'dir'), mkdir(outdir); end

buildfm('L2T2_FM', outdir, TS, STOP);
buildlin('L2T2_FM_linearity', outdir, TS, STOP);

fprintf(['\nDigital Filter Design in L2T2_FM: double-click it and enter\n' ...
    '  Response Type  Lowpass\n' ...
    '  Design Method  FIR, Window\n' ...
    '  Filter Order   Specify order, 1000 (TA instruction; the handout says 30)\n' ...
    '  Options        Scale Passband ticked, Window Kaiser, Beta 0.5\n' ...
    '  Frequency      Units Hz, Fs 1e6, Fc 1e3\n' ...
    'then click Design Filter, close the dialog, and save the model.\n\n']);
report();
end

% =====================================================================
% The handout circuit
% =====================================================================
function buildfm(MODEL, outdir, TS, STOP)
sys = newmodel(MODEL, outdir, STOP, TS, 'FixedStepDiscrete');

addarea(sys, 'FM Modulation', [216 402 865 700]);
addarea(sys, 'VCO',           [900 693 1361 914]);

addsinehz(sys, 'Sine Wave (Modulating Signal)', '1', '1/(1000*1e-6)', TS, [88 453 140 505]);

% ---- FM Modulation -----------------------------------------------------
addgain(sys, 'Gain (Sensitivity Factor)', '3000', [276 454 346 504]);
addk(sys, 'Constant (Carrier Frequency)', '9000', [278 582 328 632]);
addsum(sys, 'Add', '++', [421 464 473 520]);
addint(sys, 'Discrete-Time Integrator', TS, [549 469 609 521]);
addgain(sys, 'Gain', '2*pi', [686 471 736 521]);
addtrig(sys, 'Trigonometric Function', 'cos', [789 471 841 521]);

conn(sys, 'Sine Wave (Modulating Signal)/1', 'Gain (Sensitivity Factor)/1', 'm');
conn(sys, 'Gain (Sensitivity Factor)/1', 'Add/1');
conn(sys, 'Constant (Carrier Frequency)/1', 'Add/2');
conn(sys, 'Add/1', 'Discrete-Time Integrator/1', 'f_i (Hz)');
conn(sys, 'Discrete-Time Integrator/1', 'Gain/1');
conn(sys, 'Gain/1', 'Trigonometric Function/1', 'phase (rad)');

addscope(sys, 'Scope (Mod)', 2, [943 258 995 314], 'Message (1) and FM signal (2)', 0.002);
addspec(sys, 'Spectrum (Mod)', [1062 246 1140 334], ...
    specpairs('FM signal', 0, 25000, 50, 10, -20));
conn(sys, 'Sine Wave (Modulating Signal)/1', 'Scope (Mod)/1');
conn(sys, 'Trigonometric Function/1', 'Scope (Mod)/2', 'fm');
conn(sys, 'Trigonometric Function/1', 'Spectrum (Mod)/1');

% ---- Demodulator (phase-locked loop) -----------------------------------
p = addb(sys, 'Product', 'Product', ...
    {'simulink/Math Operations/Product', 'built-in/Product'}, [943 551 995 604]);
setp(p, '2', {'Inputs'}, {'Number of inputs'}, true);
s = addb(sys, 'Saturation', 'Saturation', ...
    {'simulink/Discontinuities/Saturation', 'built-in/Saturate'}, [1062 556 1114 606]);
setp(s, '0.5',  {'UpperLimit'}, {'Upper limit'});
setp(s, '-0.5', {'LowerLimit'}, {'Lower limit'});
addb(sys, 'Digital Filter Design', 'Digital Filter Design', { ...
    'dspfdesign/Digital Filter Design', ...
    'dsp_lib/Filtering/Filter Implementations/Digital Filter Design', ...
    'dsparch4/Digital Filter Design'}, [1156 533 1268 630]);
note(['Digital Filter Design: enter the design by hand (the dialog entries are ' ...
    'printed just above). Until then it does not filter the 18 kHz term.']);

conn(sys, 'Trigonometric Function/1', 'Product/1');
conn(sys, 'Product/1', 'Saturation/1');
conn(sys, 'Saturation/1', 'Digital Filter Design/1');

% VCO, drawn right to left as on the handout
addgain(sys, 'Gain (VCO Sensitivity)', '3000', [1275 745 1345 795]);
flipblock([sys '/Gain (VCO Sensitivity)']);
addk(sys, 'Constant (VCO Free-Running Frequency)', '9000', [1286 838 1336 888]);
addsum(sys, 'Add (VCO)', '++', [1182 755 1234 811]);
flipblock([sys '/Add (VCO)']);
addint(sys, 'Discrete-Time Integrator (VCO)', TS, [1079 761 1139 814]);
flipblock([sys '/Discrete-Time Integrator (VCO)']);
addgain(sys, 'Gain (VCO 2*pi)', '2*pi', [1003 762 1053 812]);
flipblock([sys '/Gain (VCO 2*pi)']);
addtrig(sys, 'Trigonometric Function (VCO)', 'sin', [925 762 977 812]);
flipblock([sys '/Trigonometric Function (VCO)']);
for nm = {'Gain (VCO Sensitivity)', 'Constant (VCO Free-Running Frequency)', 'Add (VCO)', ...
          'Discrete-Time Integrator (VCO)', 'Gain (VCO 2*pi)', 'Trigonometric Function (VCO)'}
    hidename([sys '/' nm{1}]);
end

conn(sys, 'Digital Filter Design/1', 'Gain (VCO Sensitivity)/1', 'demod');
conn(sys, 'Gain (VCO Sensitivity)/1', 'Add (VCO)/1');
conn(sys, 'Constant (VCO Free-Running Frequency)/1', 'Add (VCO)/2');
conn(sys, 'Add (VCO)/1', 'Discrete-Time Integrator (VCO)/1', 'f_vco (Hz)');
conn(sys, 'Discrete-Time Integrator (VCO)/1', 'Gain (VCO 2*pi)/1');
conn(sys, 'Gain (VCO 2*pi)/1', 'Trigonometric Function (VCO)/1');
conn(sys, 'Trigonometric Function (VCO)/1', 'Product/2', 'vco');

addscope(sys, 'Scope (Demod)', 2, [1394 540 1446 598], 'Message (1) and recovered (2)', 0.002);
conn(sys, 'Sine Wave (Modulating Signal)/1', 'Scope (Demod)/1');
conn(sys, 'Digital Filter Design/1', 'Scope (Demod)/2');

set_param(sys, 'Description', sprintf([ ...
    'ECSE 308 L2T2 Part 2: FM with a phase-locked-loop demodulator.\n' ...
    'Fixed-step discrete at %s s, stop %s s.\n' ...
    'Step 3: change Gain (Sensitivity Factor). Step 4: change the Sine Wave ' ...
    'Frequency (Hz) and Amplitude.'], TS, STOP));

finish(sys, outdir, MODEL);
end

% =====================================================================
% Step 2: is FM linear? FM(m1 + m2) against FM(m1) + FM(m2)
% =====================================================================
function buildlin(MODEL, outdir, TS, STOP)
% Three copies of the handout's modulator, same settings. The top one is fed
% the sum of the two sines; the other two get one sine each and their outputs
% are added. If FM were linear the two results would be identical. They are
% not: the top one has a single carrier and extra sidebands at 9 kHz +- 600 Hz
% (1000 - 400) and similar mixes; the bottom one has two carriers and no mixes.
sys = newmodel(MODEL, outdir, STOP, TS, 'FixedStepDiscrete');

addsinehz(sys, 'Sine Wave 1 (1 kHz)',   '1', '1000', TS, [40 100 92 152]);
addsinehz(sys, 'Sine Wave 2 (400 Hz)',  '1', '400',  TS, [40 330 92 382]);
addsum(sys, 'm1 + m2', '++', [160 200 200 250]);
conn(sys, 'Sine Wave 1 (1 kHz)/1', 'm1 + m2/1', 'm1');
conn(sys, 'Sine Wave 2 (400 Hz)/1', 'm1 + m2/2', 'm2');

fmtx(sys, 'FM of sum',  'm1 + m2/1',              TS, 200);
fmtx(sys, 'FM of m1',   'Sine Wave 1 (1 kHz)/1',  TS, 420);
fmtx(sys, 'FM of m2',   'Sine Wave 2 (400 Hz)/1', TS, 620);
addsum(sys, 'Sum of FMs', '++', [1000 510 1040 580]);
conn(sys, 'FM of m1 cos/1', 'Sum of FMs/1');
conn(sys, 'FM of m2 cos/1', 'Sum of FMs/2');

addscope(sys, 'Scope (Linearity)', 3, [1120 180 1172 260], ...
    'm1+m2 (1), FM of sum (2), sum of FMs (3)', 0.005);
conn(sys, 'm1 + m2/1', 'Scope (Linearity)/1');
conn(sys, 'FM of sum cos/1', 'Scope (Linearity)/2', 'FM(m1+m2)');
conn(sys, 'Sum of FMs/1', 'Scope (Linearity)/3', 'FM(m1)+FM(m2)');

addspec(sys, 'Spectrum (FM of sum)', [1120 300 1198 388], ...
    specpairs('FM(m1 + m2)', 0, 25000, 50, 12, -20));
addspec(sys, 'Spectrum (Sum of FMs)', [1120 440 1198 528], ...
    specpairs('FM(m1) + FM(m2)', 0, 25000, 50, 12, -20));
conn(sys, 'FM of sum cos/1', 'Spectrum (FM of sum)/1');
conn(sys, 'Sum of FMs/1', 'Spectrum (Sum of FMs)/1');

set_param(sys, 'Description', sprintf([ ...
    'ECSE 308 L2T2 Part 2 step 2: FM(m1+m2) against FM(m1)+FM(m2).\n' ...
    'Each modulator is the handout''s: Gain 3000, + 9000, integrator, 2*pi, cos.']));

finish(sys, outdir, MODEL);
end

function fmtx(sys, pre, src, TS, y)
% One handout modulator in a row at height y, named "<pre> <part>".
addgain(sys, [pre ' gain'], '3000', [300 y 350 y+40]);
addk(sys,   [pre ' fc'],    '9000', [300 y+60 350 y+90]);
addsum(sys, [pre ' add'],   '++',   [420 y+10 460 y+60]);
addint(sys, [pre ' int'],   TS,     [520 y+15 570 y+55]);
addgain(sys, [pre ' 2pi'],  '2*pi', [630 y+15 680 y+55]);
addtrig(sys, [pre ' cos'],  'cos',  [740 y+15 790 y+55]);
conn(sys, src, [pre ' gain/1']);
conn(sys, [pre ' gain/1'], [pre ' add/1']);
conn(sys, [pre ' fc/1'],   [pre ' add/2']);
conn(sys, [pre ' add/1'],  [pre ' int/1']);
conn(sys, [pre ' int/1'],  [pre ' 2pi/1']);
conn(sys, [pre ' 2pi/1'],  [pre ' cos/1']);
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

% =====================================================================
% Part 2 block helpers
% =====================================================================
function addsinehz(sys, name, amp, hz, ts, pos)
% DSP System Toolbox Sine Wave: discrete, Hz, one sample per frame. Falls back
% to the Simulink one in sample-based mode if this release lacks it.
b = addb(sys, name, 'Sine Wave', {'dspsrcs4/Sine Wave', 'dsp_lib/Sources/Sine Wave'}, pos, true);
if ~isempty(b)
    setp(b, 'Discrete',          {'SampleMode'},      {'Sample mode'});
    setp(b, 'Real',              {'OutComplex'},      {'Output complexity'}, true);
    setp(b, amp,                 {'Amplitude'},       {'^Amplitude'});
    setp(b, hz,                  {'Frequency'},       {'^Frequency'});
    setp(b, '0',                 {'Phase'},           {'^Phase'});
    setp(b, 'Trigonometric fcn', {'CompMethod'},      {'Computation method'}, true);
    setp(b, ts,                  {'SampleTime'},      {'^Sample time'});
    setp(b, '1',                 {'SamplesPerFrame'}, {'Samples per frame'});
    return
end
note(sprintf('%s: no DSP Sine Wave in this session, the Simulink one is used', name));
b = addb(sys, name, 'Sine Wave', {'simulink/Sources/Sine Wave', 'built-in/Sin'}, pos);
if isempty(b), return, end
setp(b, ts, {'SampleTime'}, {'Sample time'});
setp(b, sprintf('round(1/(%s*(%s)))', ts, hz), {'Samples'}, {'Samples per period'});
setp(b, amp, {'Amplitude'}, {'Amplitude'});
setp(b, 'Sample based', {'SineType'}, {'Sine type'});
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
for lib = {'dspsrcs4', 'dspfdesign', 'dspsnks4'}
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
% Everything in Part 2 is discrete, so no continuous solver is needed.
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
