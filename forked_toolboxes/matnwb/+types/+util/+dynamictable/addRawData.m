function addRawData(DynamicTable, column, data)
%ADDRAWDATA Internal method for adding data to DynamicTable given column
% name and data. Indices are determined based on data format and available
% indices.
validateattributes(column, {'char'}, {'scalartext'});

if (isprop(DynamicTable, column) && isempty(DynamicTable.(column))) ...
    || (~isprop(DynamicTable, column) && ~isKey(DynamicTable.vectordata, column))
    % No vecdata found anywhere. Initialize.
    initVecData(DynamicTable, column);
end

if isprop(DynamicTable, column)
    Vector = DynamicTable.(column);
elseif isprop(DynamicTable, 'vectorindex') && DynamicTable.vectorindex.isKey(column)
    Vector = DynamicTable.vectorindex.get(column);
else
    Vector = DynamicTable.vectordata.get(column);
end

% grab all available indices for column.
indexChain = {column};
while true
    index = types.util.dynamictable.getIndex(DynamicTable, indexChain{end});
    if isempty(index)
        break;
    end
    indexChain{end+1} = index;
end

if ~isa(Vector.data, 'types.untyped.DataPipe')
    % validate shape for appending in memory.
    checkNestedShape(data);
end

% find true nesting depth of column data.
if isa(Vector.data, 'types.untyped.DataPipe')
    depth = getNestedDataDepth(data, 'dataPipeDimension', Vector.data.axis);
else
    depth = getNestedDataDepth(data);
end

% add indices until it matches depth.
for iVec = (length(indexChain)+1):depth
    indexChain{iVec} = types.util.dynamictable.addVecInd(DynamicTable, indexChain{end});
end

% wrap until available vector indices match depth.
for iVec = (depth+1):length(indexChain)
    data = {data}; % wrap until the correct number of vector indices are satisfied.
end

% Now in index->data order.
nestedAdd(DynamicTable, flip(indexChain), data);
end

function checkNestedShape(data)
errorId = 'MatNWB:DynamicTable:AddRow:InvalidShape';
if iscell(data) && ~iscellstr(data)
    assert(isvector(data), errorId, ...
        'Wrapped cell array data must be a vector for use with ragged arrays.');
    for iCell = 1:length(data)
        checkNestedShape(data{iCell});
    end
else
    assert(ismatrix(data), errorId, 'Adding 3D and higher-rank data must use DataPipes.');
end
end

function initVecData(DynamicTable, column)
% Don't set the data until after indices are updated.
if 8 == exist('types.hdmf_common.VectorData', 'class')
    VecData = types.hdmf_common.VectorData();
else
    VecData = types.core.VectorData();
end

VecData.description = sprintf('AUTOGENERATED description for column `%s`', column);
VecData.data = [];

if isprop(DynamicTable, column)
    DynamicTable.(column) = VecData;
else
    DynamicTable.vectordata.set(column, VecData);
end
end

function depth = getNestedDataDepth(data, varargin)
p = inputParser;
p.addParameter('dataPipeDimension', [], @(x)isnumeric(x) && (isempty(x) || isscalar(x)));
p.parse(varargin{:});

depth = 1;
subData = data;
while iscell(subData) && ~iscellstr(subData)
    depth = depth + 1;
    subData = subData{1};
end

% special case where the final data is in fact multiple rows to begin
% with.
if isempty(p.Results.dataPipeDimension)
    isMultirow = (ismatrix(subData) && 1 < size(subData, 2)) ...
            || (isvector(subData) && 1 < length(subData));
else
    isMultirow = 1 < size(subData, p.Results.dataPipeDimension);
end
if isMultirow
    depth = depth + 1;
end
end

function numRows = nestedAdd(DynamicTable, indChain, data)
name = indChain{1};

if isprop(DynamicTable, name)
    Vector = DynamicTable.(name);
elseif isprop(DynamicTable, 'vectorindex') && DynamicTable.vectorindex.isKey(name)
    Vector = DynamicTable.vectorindex.get(name);
else
    Vector = DynamicTable.vectordata.get(name);
end

if isa(Vector, 'types.hdmf_common.VectorIndex') || isa(Vector, 'types.core.VectorIndex')
    if iscell(data) && ~iscellstr(data)
        numRows = length(data);
        for iEntry = 1:numRows
            nestedAdd(DynamicTable, indChain(2:end), data{iEntry});
        end
    else
        numRows = nestedAdd(DynamicTable, indChain(2:end), data);
    end

    add2Index(Vector, numRows);
else
    if ischar(data)
        data = mat2cell(data, ones(size(data, 1), 1));
    end % char matrices converted to cell arrays containing character vectors.

    if isa(Vector.data, 'types.untyped.DataPipe')
        Vector.data.append(data);
        numRows = size(data, Vector.data.axis);
    else
        numRows = add2MemData(Vector, data);
    end
end
end

function numRows = add2MemData(VectorData, data)
%ADD2MEMDATA add to in-memory data.

if isempty(VectorData.data) || isscalar(VectorData.data)
    appendBasis = data;
else
    appendBasis = VectorData.data;
end % determine the basis for finding the concatenation dimension.

if isscalar(appendBasis) || ~isvector(appendBasis) % is scalar or matrix but not vector.
    catDim = 2;
    assert(2 >= ndims(appendBasis), 'MatNWB:DynamicTable:AddRow:InvalidShape', ...
        ['addRow does not support adding to matrices with more than 2 dimensions. ' ...
        'For multi-dimensional matrices, use a DataPipe instead.']);
    numRows = size(data, 2);
else % vector data
    catDim = find(size(appendBasis) > 1);
    numRows = length(data);
end

VectorData.data = cat(catDim, VectorData.data, data);
end

function add2Index(VectorIndex, numElem)
raggedOffset = 0;
if isa(VectorIndex.data, 'types.untyped.DataPipe')
    if isa(VectorIndex.data.internal, 'types.untyped.datapipe.BlueprintPipe')...
            && ~isempty(VectorIndex.data.internal.data)
        raggedOffset = VectorIndex.data.internal.data(end);
    elseif isa(VectorIndex.data.internal, 'types.untyped.datapipe.BoundPipe')...
            && ~any(VectorIndex.data.internal.stub.dims == 0)
        raggedOffset = VectorIndex.data.internal.stub(end);
    end
elseif ~isempty(VectorIndex.data)
    raggedOffset = VectorIndex.data(end);
end

data = double(raggedOffset) + numElem;
if isa(VectorIndex.data, 'types.untyped.DataPipe')
    VectorIndex.data.append(data);
else
    VectorIndex.data = [double(VectorIndex.data); data];
end
end