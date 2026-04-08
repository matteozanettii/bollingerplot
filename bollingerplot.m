function out = bollingerplot(S)
% Per ogni elemento di S crea una figura separata con prezzo, SMA(20) e Bollinger
% Usa solo datetime per gli assi e controlli su dati mancanti.

if ~isstruct(S) || isempty(S)
    error('Input must be a non-empty struct array.');
end

L = 20; nsig = 2;
figHandles = gobjects(0);
metaTicker = string.empty;
metaLast = []; metaU = []; metaL = [];

for k = 1:numel(S)
    tt = findTimetable(S(k));
    if isempty(tt), continue; end
    tt = normalizeToUTC(tt);
    tvec = tt.Properties.RowTimes;

    price = getPriceFromTT(tt);
    if isempty(price) || all(isnan(price))
        warning('No numeric price found for entry %d. Skipping.', k);
        continue;
    end
    % Remove NaN endpoints for plotting coherence
    validIdx = ~isnan(price) & ~isnat(tvec);
    if nnz(validIdx) < 2
        warning('Too few valid points for entry %d. Skipping.', k);
        continue;
    end
    tvec = tvec(validIdx);
    price = price(validIdx);

    % Bollinger
    if numel(price) < L
        sma = movmean(price, [numel(price)-1 0]);
        msd = movstd(price, [numel(price)-1 0]);
    else
        sma = movmean(price, [L-1 0]);
        msd = movstd(price, [L-1 0]);
    end
    upper = sma + nsig*msd;
    lower = sma - nsig*msd;

    % Figure separata
    fig = figure('Name', sprintf('Bollinger - %s', char(getName(S(k),k))), ...
                 'NumberTitle','off','Color','w', 'Units','normalized', 'Position',[0.2 0.2 0.55 0.55]);
    ax = axes(fig);
    hold(ax,'on'); grid(ax,'on');
    title(ax, char(getName(S(k),k)));
    xlabel(ax,'Time'); ylabel(ax,'Price');

    % Up/Down colored segments: plot continuous but mask the other points
    d = [0; diff(price)];
    upIdx = d >= 0;
    dnIdx = d < 0;
    % Plot as lines using datetime (no conversion)
    if any(upIdx); plot(ax, tvec(upIdx), price(upIdx), '-', 'Color',[0 0.6 0], 'LineWidth',1.4); end
    if any(dnIdx); plot(ax, tvec(dnIdx), price(dnIdx), '-', 'Color',[0.85 0.15 0.15], 'LineWidth',1.4); end

    % SMA e bande
    plot(ax, tvec, sma, '-','Color',[0 0.4470 0.7410],'LineWidth',1);
    plot(ax, tvec, upper, '--','Color',[0.3 0.3 0.3],'LineWidth',0.9);
    plot(ax, tvec, lower, '--','Color',[0.3 0.3 0.3],'LineWidth',0.9);

    % Fill band using datetime directly (supported in modern MATLAB)
    try
        xpatch = [tvec; flipud(tvec)];
        ypatch = [upper; flipud(lower)];
        patch('XData', xpatch, 'YData', ypatch, 'FaceColor',[0.6 0.6 0.6], ...
              'FaceAlpha',0.08, 'EdgeColor','none', 'Parent', ax);
    catch
        % se la versione MATLAB non supporta patch con datetime, salta fill
    end

    % Opzionale: disegna markers sugli ultimi punti per evidenziare
    plot(ax, tvec(end), price(end), 'o', 'MarkerFaceColor',[0 0.4470 0.7410], 'MarkerEdgeColor','k');

    % Imposta limiti con un piccolo margine
    try
        xr = [tvec(1) tvec(end)];
        yr = [min(lower(~isnan(lower))) max(upper(~isnan(upper)))];
        if any(isnan(yr))
            yr = [min(price) max(price)];
        end
        pad = 0.06 * (yr(2)-yr(1));
        ylim(ax, [yr(1)-pad, yr(2)+pad]);
        xlim(ax, xr);
    catch
        % fallback: lascia autoscale
    end

    % Legenda minima
    legend(ax, {'Price up','Price down','SMA','Upper','Lower'}, 'Location','best');

    hold(ax,'off');

    % salva metadata
    figHandles(end+1,1) = fig; %#ok<SAGROW>
    metaTicker(end+1,1) = getName(S(k),k); %#ok<SAGROW>
    metaLast(end+1,1) = price(end); %#ok<SAGROW>
    metaU(end+1,1) = upper(end); %#ok<SAGROW>
    metaL(end+1,1) = lower(end); %#ok<SAGROW>
end

out.figHandles = figHandles;
out.summary = table(metaTicker.', metaLast.', metaU.', metaL.', ...
    'VariableNames', {'Ticker','LastPrice','UpperLast','LowerLast'});

end

%% --- helper functions (identiche a prima) ------------------------------

function tt = findTimetable(entry)
    tt = [];
    if isempty(entry), return; end
    f = fieldnames(entry);
    cands = {'TT','tt','Table','table','Data','data'};
    for i = 1:numel(cands)
        if ismember(cands{i}, f)
            val = entry.(cands{i});
            if istimetable(val), tt = val; return; end
            if istable(val)
                if ismember('Time', val.Properties.VariableNames)
                    try tt = table2timetable(val,'RowTimes','Time'); return; end
                elseif ismember('t', val.Properties.VariableNames)
                    try tt = table2timetable(val,'RowTimes','t'); return; end
                end
            end
        end
    end
    for i = 1:numel(f)
        val = entry.(f{i});
        if istimetable(val), tt = val; return; end
    end
end

function ttOut = normalizeToUTC(ttIn)
    ttOut = ttIn;
    if isempty(ttIn), return; end
    try
        t = ttOut.Properties.RowTimes;
        if isempty(t.TimeZone)
            t.TimeZone = 'UTC';
            ttOut.Properties.RowTimes = t;
        else
            ttOut.Properties.RowTimes = datetime(t,'TimeZone','UTC');
        end
    catch
        ttOut = ttIn;
    end
end

function p = getPriceFromTT(tt)
    p = [];
    if isempty(tt), return; end
    vars = tt.Properties.VariableNames;
    prefer = {'AdjClose','Adj_Close','AdjClosePrice','AdjustedClose','Close','close'};
    for i = 1:numel(prefer)
        if ismember(prefer{i}, vars)
            p = tt.(prefer{i}); return;
        end
    end
    types = varfun(@class, tt, 'OutputFormat','cell');
    idx = find(ismember(types,{'double','single'}),1,'last');
    if ~isempty(idx)
        p = tt{:,idx};
    end
end

function name = getName(entry, idx)
    name = '';
    if isfield(entry,'Ticker'), name = string(entry.Ticker); end
    if isempty(name) && isfield(entry,'ticker'), name = string(entry.ticker); end
    if isempty(name)
        fld = fieldnames(entry);
        for f = 1:numel(fld)
            val = entry.(fld{f});
            if ischar(val) || isstring(val)
                name = string(val); break;
            end
        end
    end
    if isempty(name), name = sprintf('T%d', idx); end
end
