function build_L2T2_sc
%BUILD_L2T2_SC  ECSE 308 L2T2 Part 1, section II: the DSB-SC AM system.
%
%   build_L2T2_sc      builds models/L2T2_DSB_SC.slx under the current folder
%
% Draws the handout's page 7 circuit block for block and wire for wire, with
% every parameter from page 8 typed in:
%
%   Source        Sine Wave 1, 2, 3 -> Add                      m(t)
%   Modulation    m(t) x Sine Wave (Mod)          = m(t) cos(wc t)
%                 No DC bias this time, so no carrier line in the spectrum.
%   Channel       AWGN Channel, variance 1e-2
%   Receiver      Analog Filter Design (BPF), Butterworth bandpass, order 8,
%                 14.3 to 15.8 kHz
%   Demodulation  x Sine Wave (Demod), a local copy of the carrier, then
%                 Analog Filter Design (LPF), Butterworth lowpass, order 8,
%                 800 Hz.  m cos^2 = m/2 + (m/2) cos(2 wc t); the LPF keeps m/2.
%
% plus the six Scopes and the six Spectrum Analyzers, each analyzer behind a
% Rate Transition, as drawn. The handout labels the pair after the bandpass
% filter "(HPF)"; the names are kept as printed.
%
% Settings the handout leaves open, matched to the section I model that ran:
%
%   * Sine waves: Simulink Sine Wave, time based, rad/s as printed on page 8,
%     sample time 1e-6 s. Solver fixed-step ode4 at 1e-6 s, because the two
%     Analog Filter Design blocks are continuous-time. Stop time 0.5 s.
%   * Every Rate Transition at 2e-5 s (page 8), so every analyzer sees 50 kHz
%     and shows -25 to +25 kHz.
%   * Spectrum Analyzers two-sided, dBm, RBW 10 Hz, peak finder on. Source and
%     LPF zoomed to -1 to +1 kHz; the others show the full span.
%   * Scopes show 20 ms, two periods of the 100 Hz pattern of the source.
%
% Ends by reading every parameter back (ok / CHECK), listing which library each
% block came from, and compiling the diagram (Ctrl+D), before it saves.
%
% Needs Simulink, DSP System Toolbox, Communications Toolbox and Signal
% Processing Toolbox.

MODEL = 'L2T2_DSB_SC';
TS    = '1e-6';
RT    = '2e-5';
STOP  = '0.5';

note('reset');
checkproducts();
outdir = fullfile(pwd, 'models');
if ~exist(outdir, 'dir'), mkdir(outdir); end
sys = newmodel(MODEL, outdir, STOP, TS);

addarea(sys, 'Source',       [30 540 230 1000]);
addarea(sys, 'Modulation',   [400 770 610 960]);
addarea(sys, 'Demodulation', [1185 575 1600 885]);

% ---- Source ------------------------------------------------------------
addsine(sys, 'Sine Wave 1', '1',   '1000*pi', '0', TS, [60 705 112 755]);
addsine(sys, 'Sine Wave 2', '3',   '600*pi',  '0', TS, [60 805 112 855]);
addsine(sys, 'Sine Wave 3', '1.5', '1200*pi', '0', TS, [60 915 112 965]);
addsum(sys, 'Add', '+++', [160 805 210 865]);
conn(sys, 'Sine Wave 1/1', 'Add/1');
conn(sys, 'Sine Wave 2/1', 'Add/2');
conn(sys, 'Sine Wave 3/1', 'Add/3');

addscope(sys, 'Scope (Source)', 1, [305 525 355 580], 'Source m(t)');
addrt(sys, 'RT (Source)', RT, [370 595 430 655]);
addspec(sys, 'Spectrum (Source)', [475 445 540 530], specsc('Source', -1000, 1000, 6));
conn(sys, 'Add/1', 'Scope (Source)/1', 'm');
conn(sys, 'Add/1', 'RT (Source)/1');
conn(sys, 'RT (Source)/1', 'Spectrum (Source)/1');

% ---- Modulation (no DC bias) --------------------------------------------
addsine(sys, 'Sine Wave (Mod)', '1', '30000*pi', 'pi/2', TS, [420 855 470 905]);
p = addb(sys, 'Product (Mod)', 'Product', ...
    {'simulink/Math Operations/Product', 'built-in/Product'}, [540 820 585 870]);
setp(p, '2', {'Inputs'}, {'Number of inputs'}, true);
conn(sys, 'Add/1', 'Product (Mod)/1');
conn(sys, 'Sine Wave (Mod)/1', 'Product (Mod)/2', 'carrier');

addscope(sys, 'Scope (Mod)', 2, [870 560 920 615], 'DSB-SC signal (1) and source m(t) (2)');
addrt(sys, 'RT (Mod)', RT, [715 455 775 515]);
addspec(sys, 'Spectrum (Mod)', [860 360 925 445], specsc('Mod', [], [], 12));
conn(sys, 'Product (Mod)/1', 'Scope (Mod)/1', 'dsbsc');
conn(sys, 'Add/1', 'Scope (Mod)/2');
conn(sys, 'Product (Mod)/1', 'RT (Mod)/1');
conn(sys, 'RT (Mod)/1', 'Spectrum (Mod)/1');

% ---- Channel and the bandpass filter ------------------------------------
a = addb(sys, 'AWGN Channel', 'AWGN Channel', ...
    {'commchan3/AWGN Channel', 'commlib/Channels/AWGN Channel'}, [800 695 940 775]);
setp(a, 'randseed',           {'seed'},      {'Initial seed'});
setp(a, 'Variance from mask', {'noiseMode'}, {'^Mode'});
setp(a, '1e-2',               {'variance'},  {'^Variance'});
conn(sys, 'Product (Mod)/1', 'AWGN Channel/1');

addscope(sys, 'Scope (Rx)', 1, [1075 565 1125 620], 'Received (DSB-SC + noise)');
addrt(sys, 'RT (Rx)', RT, [970 470 1030 530]);
addspec(sys, 'Spectrum (Rx)', [1045 360 1110 445], specsc('Rx', [], [], 12));
conn(sys, 'AWGN Channel/1', 'Scope (Rx)/1', 'rx');
conn(sys, 'AWGN Channel/1', 'RT (Rx)/1');
conn(sys, 'RT (Rx)/1', 'Spectrum (Rx)/1');

BPF = 'Analog Filter Design (BPF)';
addbutter(sys, BPF, 'Bandpass', {'14300*2*pi', '15800*2*pi'}, [1050 695 1150 780]);
conn(sys, 'AWGN Channel/1', [BPF '/1']);

addscope(sys, 'Scope (HPF)', 1, [1265 600 1315 655], 'After the bandpass filter');
addrt(sys, 'RT (HPF)', RT, [1185 470 1245 530]);
addspec(sys, 'Spectrum (HPF)', [1260 360 1325 445], specsc('HPF (after the BPF)', [], [], 12));
conn(sys, [BPF '/1'], 'Scope (HPF)/1', 'bpf');
conn(sys, [BPF '/1'], 'RT (HPF)/1');
conn(sys, 'RT (HPF)/1', 'Spectrum (HPF)/1');

% ---- Demodulation: coherent, local carrier then lowpass ------------------
addsine(sys, 'Sine Wave (Demod)', '1', '30000*pi', 'pi/2', TS, [1215 785 1265 835]);
q = addb(sys, 'Product (Demod)', 'Product', ...
    {'simulink/Math Operations/Product', 'built-in/Product'}, [1320 730 1365 780]);
setp(q, '2', {'Inputs'}, {'Number of inputs'}, true);
conn(sys, [BPF '/1'], 'Product (Demod)/1');
conn(sys, 'Sine Wave (Demod)/1', 'Product (Demod)/2', 'local carrier');

addscope(sys, 'Scope (Demod)', 1, [1470 600 1520 655], 'After the demodulating product');
addrt(sys, 'RT (Demod)', RT, [1385 470 1445 530]);
addspec(sys, 'Spectrum (Demod)', [1460 360 1525 445], specsc('Demod (before the LPF)', [], [], 12));
conn(sys, 'Product (Demod)/1', 'Scope (Demod)/1', 'product');
conn(sys, 'Product (Demod)/1', 'RT (Demod)/1');
conn(sys, 'RT (Demod)/1', 'Spectrum (Demod)/1');

LPF = 'Analog Filter Design (LPF)';
addbutter(sys, LPF, 'Lowpass', {'800*2*pi'}, [1475 710 1570 800]);
conn(sys, 'Product (Demod)/1', [LPF '/1']);

addscope(sys, 'Scope (LPF)', 2, [1710 620 1760 675], 'Recovered (1) and source m(t) (2)');
addrt(sys, 'RT (LPF)', RT, [1615 470 1675 530]);
addspec(sys, 'Spectrum (LPF)', [1690 360 1755 445], specsc('LPF (recovered)', -1000, 1000, 6));
conn(sys, [LPF '/1'], 'Scope (LPF)/1', 'recovered');
conn(sys, 'Add/1', 'Scope (LPF)/2');
conn(sys, [LPF '/1'], 'RT (LPF)/1');
conn(sys, 'RT (LPF)/1', 'Spectrum (LPF)/1');

set_param(sys, 'Description', sprintf([ ...
    'ECSE 308 L2T2 Part 1, section II: DSB-SC AM with coherent demodulation.\n' ...
    'Sources sampled at %s s, fixed-step ode4 at %s s, stop %s s.\n' ...
    'Rate Transitions at %s s; spectra two-sided.'], TS, TS, STOP, RT));

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
% Section II helpers
% =====================================================================
function addsine(sys, name, amp, w, phase, ts, pos)
% Simulink Sine Wave, time based, frequency in rad/s exactly as page 8 prints it.
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

function pairs = specsc(ttl, f1, f2, npeaks)
% Two-sided power spectrum in dBm at RBW 10 Hz, peak finder on. Empty f1/f2
% means the full span, -25 to +25 kHz at the 50 kHz Rate Transition rate.
pairs = {'Title', ttl, 'ShowLegend', true, ...
    'SpectrumType', {'Power', 'power'}, 'SpectrumUnits', 'dBm', ...
    'PlotAsTwoSidedSpectrum', true};
if isempty(f1)
    pairs = [pairs, {'FrequencySpan', {'Full', 'full'}}];
else
    pairs = [pairs, {'FrequencySpan', {'Start and stop frequencies', 'start-and-stop-frequencies'}, ...
        'StartFrequency', f1, 'StopFrequency', f2}];
end
pairs = [pairs, { ...
    '?FrequencyResolutionMethod', {'RBW', 'rbw'}, ...
    'RBWSource', {'Property', 'property'}, 'RBW', 10, ...
    'AveragingMethod', {'Running', 'running'}, ...
    {'SpectralAverages', 'NumSpectralAverages'}, 4, ...
    {'PeakFinder.Enable', 'PeakFinder.Enabled'}, true, ...
    'PeakFinder.NumPeaks', npeaks, 'PeakFinder.LabelPeaks', true, ...
    '?PeakFinder.MinHeight', 0}];
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
