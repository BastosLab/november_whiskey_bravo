classdef ScratchData < types.core.NWBData & types.untyped.DatasetClass
% SCRATCHDATA Any one-off datasets


% REQUIRED PROPERTIES
properties
    notes; % REQUIRED (char) Any notes the user has about the dataset being stored
end

methods
    function obj = ScratchData(varargin)
        % SCRATCHDATA Constructor for ScratchData
        obj = obj@types.core.NWBData(varargin{:});
        
        
        p = inputParser;
        p.KeepUnmatched = true;
        p.PartialMatching = false;
        p.StructExpand = false;
        addParameter(p, 'notes',[]);
        misc.parseSkipInvalidName(p, varargin);
        obj.notes = p.Results.notes;
        if strcmp(class(obj), 'types.core.ScratchData')
            types.util.checkUnset(obj, unique(varargin(1:2:end)));
        end
    end
    %% SETTERS
    function obj = set.notes(obj, val)
        obj.notes = obj.validate_notes(val);
    end
    %% VALIDATORS
    
    function val = validate_data(obj, val)
    end
    function val = validate_notes(obj, val)
        val = types.util.checkDtype('notes', 'char', val);
        if isa(val, 'types.untyped.DataStub')
            if 1 == val.ndims
                valsz = [val.dims 1];
            else
                valsz = val.dims;
            end
        elseif istable(val)
            valsz = [height(val) 1];
        elseif ischar(val)
            valsz = [size(val, 1) 1];
        else
            valsz = size(val);
        end
        validshapes = {[1]};
        types.util.checkDims(valsz, validshapes);
    end
    %% EXPORT
    function refs = export(obj, fid, fullpath, refs)
        refs = export@types.core.NWBData(obj, fid, fullpath, refs);
        if any(strcmp(refs, fullpath))
            return;
        end
        io.writeAttribute(fid, [fullpath '/notes'], obj.notes);
    end
end

end