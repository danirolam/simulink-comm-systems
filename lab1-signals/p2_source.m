function p2_source(src, model)
%P2_SOURCE  Swap the source block in the ECSE 308 L1T1 Part 2 circuit.
%
%   p2_source sine    100 Hz sine                 (step 1)
%   p2_source tri     5 Hz triangle               (step 2)
%   p2_source sq50    2 Hz square, 50% duty       (step 3)
%   p2_source sq20    2 Hz square, 20% duty       (step 4)
%   p2_source sum3    sum of three sines          (step 5)
%   p2_source rx      sum3 with the gain at 10    (steps 6, 7, 8)
%
%   p2_source(src, 'modelname')  to name the model explicitly. With no second
%   argument it uses whichever model is open, so the file can be called
%   anything.
%
% Only the source changes. Everything from the Slider Gain onward is left
% exactly as it is, filters included, so a hand-entered Filter Designer setting
% survives every swap.
%
% Each call also:
%   - forces Random Source (Noise) to Gaussian, which the handout requires and
%     which the block quietly reverts to Uniform when it is re-added
%   - frames Spectrum (Source) for that source: one-sided, running average,
%     the right span, the right number of peaks
%   - sets the Slider Gain to 1 for steps 1 to 5 and 10 for steps 6 to 8
%   - prints the values the run should produce, so a bad reading is caught
%     before it becomes a screenshot

if nargin < 1 || isempty(src)
    error('p2_source:usage', 'usage: p2_source sine|tri|sq50|sq20|sum3|rx');
end
src = lower(strtrim(char(src)));

% ---- find the model ---------------------------------------------------
if nargin < 2 || isempty(model)
    open = find_system('type', 'block_diagram', 'BlockDiagramType', 'model');
    open = setdiff(open, {'simulink'});
    if isempty(open)
        error('p2_source:noModel', 'No model is open. Open the circuit first, or call p2_source(''%s'', ''yourModelName'').', src);
    end
    model = open{1};
    if numel(open) > 1
        try, model = bdroot(gcs); catch, end
    end
end
model = char(model);
fprintf('model: %s\n', model);

% ---- what we are about to build ---------------------------------------
switch src
    case 'sine', gain = 1;  lo = 0; hi = 500; rbw = 1;   np = 1;
    case 'tri',  gain = 1;  lo = 0; hi = 50;  rbw = 0.5; np = 5;
    case 'sq50', gain = 1;  lo = 0; hi = 50;  rbw = 0.5; np = 5;
    case 'sq20', gain = 1;  lo = 0; hi = 50;  rbw = 0.5; np = 5;
    case 'sum3', gain = 1;  lo = 0; hi = 150; rbw = 1;   np = 3;
    case 'rx',   gain = 10; lo = 0; hi = 150; rbw = 1;   np = 3;
    otherwise
        error('p2_source:badSource', 'source must be sine, tri, sq50, sq20, sum3 or rx');
end

% ---- clear whatever is in the source position -------------------------
dropsource(model);

% ---- place the new one -------------------------------------------------
switch src
    case 'sine'
        out = addsine(model, 'Sine Wave (Source)', 1, 100, [40 291 91 348]);
    case 'tri'
        out = addtri(model, 'Triangle Generator', [40 291 91 348]);
    case 'sq50'
        out = addpulse(model, 'Pulse Generator', 5000, 2500, [40 291 91 348]);
    case 'sq20'
        out = addpulse(model, 'Pulse Generator', 5000, 1000, [40 291 91 348]);
    otherwise   % sum3 and rx
        addsine(model, 'Sine Wave 1', 0.5, 1000, [40 200 91 257]);
        addsine(model, 'Sine Wave 2', 2,   500,  [40 291 91 348]);
        addsine(model, 'Sine Wave 3', 1.5, 100,  [40 382 91 439]);
        a = addblk(model, 'Sum of 3', {'simulink/Math Operations/Add', 'built-in/Sum'}, [150 291 200 350]);
        setp(a, '+++', {'Inputs'});
        setp(a, 'rectangular', {'IconShape'});
        conn(model, 'Sine Wave 1/1', 'Sum of 3/1');
        conn(model, 'Sine Wave 2/1', 'Sum of 3/2');
        conn(model, 'Sine Wave 3/1', 'Sum of 3/3');
        out = 'Sum of 3';
end

% ---- wire it to the three things that read the source ------------------
for dst = {'Scope (Source)', 'Spectrum (Source)', 'Slider Gain'}
    if hasblock(model, dst{1})
        conn(model, [out '/1'], [dst{1} '/1']);
    else
        warn('no block named "%s" to connect to', dst{1});
    end
end

% ---- the things that are easy to get wrong -----------------------------
setgain(model, gain);
fixnoise(model);
framespec(model, 'Spectrum (Source)', lo, hi, rbw, np);

fprintf('\nsource is now "%s", Slider Gain %g\n', out, gain);
expected(src);
fprintf('Save the model (Ctrl+S) before you screenshot.\n\n');
end

% =====================================================================
function expected(src)
fprintf('\nwhat this run should produce\n');
switch src
    case 'sine'
        row('Display (Signal Power)', '-3.01 dBW');
        row('P1  100 Hz', '26.99 dBm');
    case 'tri'
        row('Display (Signal Power)', '-4.77 dBW');
        row('P1    5 Hz', '25.17 dBm');
        row('P2   15 Hz', '6.08 dBm');
        row('P3   25 Hz', '-2.79 dBm');
        row('P4   35 Hz', '-8.64 dBm');
        row('P5   45 Hz', '-13.00 dBm');
        fprintf('    nothing at 10, 20 or 30 Hz\n');
    case 'sq50'
        row('Display (Signal Power)', '-3.01 dBW');
        row('P1    0 Hz', '23.98 dBm   (DC is strongest)');
        row('P2    2 Hz', '23.07 dBm');
        row('P3    6 Hz', '13.52 dBm');
        row('P4   10 Hz', '9.09 dBm');
        row('P5   14 Hz', '6.17 dBm');
        fprintf('    nothing at 4, 8 or 12 Hz\n');
    case 'sq20'
        row('Display (Signal Power)', '-6.99 dBW');
        row('P1    2 Hz', '18.45 dBm   (fundamental is strongest now)');
        row('P2    4 Hz', '16.61 dBm');
        row('P3    0 Hz', '16.02 dBm');
        row('P4    6 Hz', '13.09 dBm');
        row('P5    8 Hz', '6.41 dBm');
        fprintf('    nulls at 10, 20 and 30 Hz\n');
    case {'sum3', 'rx'}
        row('Display (Signal Power)', '+5.12 dBW at gain 1, +25.12 at gain 10');
        row('P1   20 Hz', '33.01 dBm');
        row('P2  100 Hz', '30.51 dBm');
        row('P3   10 Hz', '20.97 dBm');
        if strcmp(src, 'rx')
            fprintf('\n    Display (Noise Power)  0.0 dBW\n');
            fprintf('    Display (Rx SNR)      +25.12 dB\n');
            fprintf('    For steps 6 and 7 set Spectrum (Rx) and Spectrum (Filtered)\n');
            fprintf('    to FULL span: the flat noise floor is the answer to Q6.\n');
        end
end
end

function row(a, b)
fprintf('    %-24s %s\n', a, b);
end

% =====================================================================
function dropsource(model)
% Remove whatever currently feeds the Slider Gain, and its own feeders if it is
% an adder, leaving everything downstream untouched.
names = {'Sine Wave (Source)', 'Triangle Generator', 'Pulse Generator', ...
         'Sum of 3', 'Sine Wave 1', 'Sine Wave 2', 'Sine Wave 3', ...
         'Sine Wave', 'Repeating Sequence Interpolated'};
for k = 1:numel(names)
    blk = [model '/' names{k}];
    if getSimulinkBlockHandle(blk) <= 0, continue, end
    cutlines(blk);
    try
        delete_block(blk);
    catch ME
        warn('could not remove "%s" (%s)', names{k}, oneline(ME.message));
    end
end
% anything still dangling into the three readers
for dst = {'Scope (Source)', 'Spectrum (Source)', 'Slider Gain'}
    blk = [model '/' dst{1}];
    if getSimulinkBlockHandle(blk) <= 0, continue, end
    try
        ph = get_param(blk, 'PortHandles');
        for h = ph.Inport
            l = get_param(h, 'Line');
            if l > 0, delete_line(l); end
        end
    catch
    end
end
end

function cutlines(blk)
try
    ph = get_param(blk, 'PortHandles');
    for h = [ph.Inport, ph.Outport]
        try
            l = get_param(h, 'Line');
            if l > 0, delete_line(l); end
        catch
        end
    end
catch
end
end

% =====================================================================
function out = addsine(model, name, amp, samples, pos)
b = addblk(model, name, {'simulink/Sources/Sine Wave', 'built-in/Sin'}, pos);
% Sample time first: the block refuses 'Sample based' while it is still
% continuous at 0.
setp(b, '1e-4',           {'SampleTime'});
setp(b, num2str(samples), {'Samples'});
setp(b, num2str(amp),     {'Amplitude'});
setp(b, '0',              {'Bias'});
setp(b, '0',              {'Offset'});
setp(b, 'Sample based',   {'SineType'});
out = name;
end

function out = addpulse(model, name, period, width, pos)
b = addblk(model, name, {'simulink/Sources/Pulse Generator', 'built-in/DiscretePulseGenerator'}, pos);
setp(b, 'Sample based',  {'PulseType'});
setp(b, '1',             {'Amplitude'});
setp(b, num2str(period), {'Period'});
setp(b, num2str(width),  {'PulseWidth'});
setp(b, '0',             {'PhaseDelay'});
setp(b, '1e-4',          {'SampleTime'});
out = name;
end

function out = addtri(model, name, pos)
% The handout's Triangle Generator is a Simscape Electrical block and is not on
% this licence. Repeating Sequence Interpolated gives the same waveform:
% symmetric triangle, peak 1, 5 Hz.
b = addblk(model, name, {'simulink/Sources/Repeating Sequence Interpolated'}, pos);
setp(b, '[0 1 0 -1 0]',          {'OutValues'});
setp(b, '[0 0.05 0.1 0.15 0.2]', {'TimeValues'});
setp(b, '1e-4',                  {'tsamp'});
out = name;
end

% =====================================================================
function setgain(model, g)
blk = [model '/Slider Gain'];
if getSimulinkBlockHandle(blk) <= 0
    warn('no Slider Gain block found');
    return
end
setp(blk, num2str(g), {'gain', 'Gain'});
end

function fixnoise(model)
% The handout asks for Gaussian. The Random Source block defaults to Uniform
% and this has now reverted three times, so it is checked on every swap.
r = find_system(model, 'RegExp', 'on', 'Name', '^Random Source');
if isempty(r)
    warn('no Random Source block found');
    return
end
blk = r{1};
before = '';
try, before = char(get_param(blk, 'SrcType')); catch, end
setp(blk, 'Gaussian', {'SrcType'});
setp(blk, '0',        {'MeanVal'});
setp(blk, '1',        {'VarVal', 'VarianceVal'});
setp(blk, '1e-4',     {'SampTime', 'Ts'});
after = '';
try, after = char(get_param(blk, 'SrcType')); catch, end
if ~isempty(before) && ~strcmpi(before, after)
    fprintf('Random Source: %s -> %s\n', before, after);
end
if ~isempty(after) && ~strncmpi(after, 'Gauss', 5)
    warn('Random Source is still "%s". Set Source type to Gaussian by hand.', after);
end
end

function framespec(model, name, lo, hi, rbw, npeaks)
% One-sided, running average of 1, a span that fits the harmonics, and only as
% many peaks as there are real lines. Two-sided costs 3.01 dB on every line and
% VBW averaging smears a narrow one, so both are set explicitly.
blk = [model '/' name];
if getSimulinkBlockHandle(blk) <= 0
    warn('no block named "%s"', name);
    return
end
try
    cfg = get_param(blk, 'ScopeConfiguration');
catch
    warn('"%s" has no ScopeConfiguration; set span and peaks from the toolstrip', name);
    return
end
set_cfg(cfg, 'PlotAsTwoSidedSpectrum', false);
set_cfg(cfg, 'SpectrumType',   {'Power', 'power'});
set_cfg(cfg, 'SpectrumUnits',  'dBm');
set_cfg(cfg, 'FrequencySpan',  {'Start and stop frequencies', 'start-and-stop-frequencies'});
set_cfg(cfg, 'StartFrequency', lo);
set_cfg(cfg, 'StopFrequency',  hi);
set_cfg(cfg, 'RBWSource',      {'Property', 'property'});
set_cfg(cfg, 'RBW',            rbw);
set_cfg(cfg, 'AveragingMethod',  {'Running', 'running', 'Exponential'});
set_cfg(cfg, {'SpectralAverages', 'NumSpectralAverages'}, 1);
set_cfg(cfg, {'PeakFinder.Enable', 'PeakFinder.Enabled'}, true);
set_cfg(cfg, 'PeakFinder.NumPeaks',   npeaks);
set_cfg(cfg, 'PeakFinder.LabelPeaks', true);
fprintf('Spectrum (Source): one-sided, %g to %g Hz, RBW %g Hz, %d peak(s)\n', lo, hi, rbw, npeaks);
end

function set_cfg(cfg, prop, val)
if ischar(prop), prop = {prop}; end
if ~iscell(val), val = {val}; end
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
                return
            catch
            end
        end
    end
end
end

% =====================================================================
function b = addblk(model, name, cands, pos)
b = '';
dst = [model '/' name];
for k = 1:numel(cands)
    try
        add_block(cands{k}, dst, 'Position', pos);
        b = dst;
        return
    catch
    end
end
warn('block "%s" not found in the library; add it by hand and name it "%s"', cands{1}, name);
end

function setp(blk, val, names)
if isempty(blk), return, end
known = {};
try
    dp = get_param(blk, 'DialogParameters');
    if isstruct(dp), known = fieldnames(dp); end
catch
end
for k = 1:numel(names)
    if any(strcmp(known, names{k}))
        try
            set_param(blk, names{k}, val);
            return
        catch
        end
    end
end
for k = 1:numel(names)
    try
        set_param(blk, names{k}, val);
        return
    catch
    end
end
warn('%s: could not set "%s" to %s', blk, names{1}, val);
end

function conn(model, src, dst)
try
    add_line(model, src, dst, 'autorouting', 'on');
catch ME
    warn('draw %s -> %s by hand (%s)', src, dst, oneline(ME.message));
end
end

function tf = hasblock(model, name)
tf = getSimulinkBlockHandle([model '/' name]) > 0;
end

function warn(fmt, varargin)
fprintf(2, '  ! %s\n', sprintf(fmt, varargin{:}));
end

function s = oneline(msg)
s = strtrim(regexprep(msg, '\s+', ' '));
end
