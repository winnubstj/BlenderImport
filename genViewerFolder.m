function [outputArg1,outputArg2] = genViewerFolder(inputFile,varargin)
%% Parse input.
p = inputParser;
p.addOptional('inputFile',[],@(x) ischar(x));
p.addParameter('OutputFolder',[],@ischar);
p.addParameter('MeshFile',fullfile('//dm11/mousebrainmicro/Allen_compartments/Matlab/allenMeshCorrectedAxis.mat'),@(x) ischar(x));
p.parse(varargin{:});
Inputs = p.Results;

%% Check if output/ input file provided.
if isempty(Inputs.inputFile)
    [file,path] = uigetfile('.mat','Open Reconstruction Viewer file');
    if path==0
        return
    end
    Inputs.inputFile = fullfile(path,file);
end

%% Get output Folder
if isempty(Inputs.OutputFolder)
    [path,~,~] = fileparts(Inputs.inputFile);
    [path] = uigetdir(path,'Save as..');
    if path==0
        return
    end
    Inputs.OutputFolder = fullfile(path);
end

%% Make output folders.
swcFolder = fullfile(Inputs.OutputFolder,'swcs');
meshFolder = fullfile(Inputs.OutputFolder,'meshes');
if ~isfolder(swcFolder), mkdir(swcFolder); end
if ~isfolder(meshFolder), mkdir(meshFolder); end

%% Load session.
fprintf('\nLoading Session..');
load(Inputs.inputFile);

%% Get anatomy Info.
fprintf('\nLoading Anatomy Info..');
load(Inputs.MeshFile);

%% get visible Neurons.
indVis = [Session.Neurons.Visibility];
Session.Neurons = Session.Neurons(indVis);
names = {Session.Neurons.Name};
names = cellfun(@(x) x(1:6),names,'UniformOutput',false);
[names,ind,~] = unique(names);
neurons = struct('id','','color',[]);
for i =1:size(names,2)
    fprintf('\nWriting Neuron %i\\%i',i,size(names,2));
    % Settings for neuron.
    cNeuron = ind(i);
    name = names{i};
    color = Session.Neurons(cNeuron).Color;
    neurons(i).id = name;
    neurons(i).color = color;
    % Write swcs.
    allFields = {Session.Neurons.Name};
    indNeuron = cellfun(@(x) strcmpi(x(1:6),name),allFields,'UniformOutput',false);
    indNeuron = find([indNeuron{:}]);
    % go through matching neurons
    for iNeuron = 1:size(indNeuron,2)
        cNeuron = indNeuron(iNeuron);
        cName = allFields{cNeuron}(1:6);
        type = allFields{cNeuron}(end);
        % make swc.
        swc = Session.Neurons(cNeuron).Nodes;
        swc = [ swc(:,5),zeros(size(swc,1),1),swc(:,1:3),ones(size(swc,1),1),swc(:,4)];
        % make node type list.
        swc(1,2) = 1;
        [N,edges] = histcounts(swc(:,7),[1:size(swc,1)]);
        swc(find(N>1),2) = 5;
        swc(find(N==0),2) = 6;
        % generate output name
        if strcmpi(type,'a')
            typeName = 'axon';
        else
            typeName = 'dendrite';
        end
        outputFile = fullfile(swcFolder,...
            sprintf('%s_%s.swc',cName,typeName));
        fid = fopen(outputFile,'w');
        % Header.
        fprintf(fid,'# ORIGINAL_SOURCE MouseLight Database');
        fprintf(fid,'\n# OFFSET 0 0 0');
        fprintf(fid,'\n# COLOR %.4f,%.4f,%.4f',color);
        fprintf(fid,'\n# GENERATED ON %s',datestr(now,'yy/mm/dd HH:MM'));
        fprintf(fid,'\n%i %i %.6f  %.6f  %.6f  %.6f %i',swc');
        fclose(fid);
    end
end


%% get Area's
ind = find(Session.visibleStructures);
ind = [ind;712]; %add whole brain just in case.
anatomy = struct();
counter = 0;
for iArea = 1:length(ind)
   fprintf('\nWriting Area %i\\%i',iArea,length(ind));
   cArea = ind(iArea);
   if cArea~=712
       counter = counter+1;
       anatomy(counter).acronym = allenMesh(cArea).acronym;
       anatomy(counter).color = Session.structProps(iArea).FaceColor;
   end
   % write obj.
   dimOrder = [1,2,3];
    % get Mesh Info.
    v = allenMesh(cArea).v(:,dimOrder);
    vn = allenMesh(cArea).vn(:,dimOrder);
    f = allenMesh(cArea).f;
    
    % Create result file.
    nameFile = sprintf('%s_%i',allenMesh(cArea).acronym,allenMesh(cArea).id);
    nameFile = strrep(nameFile,'\','-');
    nameFile = strrep(nameFile,'/','-');
    nameFile = strrep(nameFile,',','.');
    fOut = fopen(fullfile(meshFolder,[nameFile,'.obj']),'w');
    
    % Write obj.
    outputStr = '';
    outputStr = [outputStr, sprintf('# Brain compartment 3D surface mesh\n')];
    outputStr = [outputStr,sprintf('# Compartment name: ''%s'' \n', allenMesh(cArea).name)];
    outputStr = [outputStr,sprintf('# Compartment acronym: ''%s'' \n', allenMesh(cArea).acronym)];
    outputStr = [outputStr,sprintf('# Compartment id: %i \n', allenMesh(cArea).id)];
    outputStr = [outputStr,sprintf('# parent id: %i \n', allenMesh(cArea).parent_id)];
    outputStr = [outputStr,sprintf('# hierarchy path: %s \n', allenMesh(cArea).hierarchy_path)];
    outputStr = [outputStr,sprintf('# Compartment color: 0x%s \n', allenMesh(cArea).color)];
    outputStr = [outputStr,sprintf('# graph order: %i \n', allenMesh(cArea).graph_order)];
    outputStr = [outputStr,sprintf('# atlas id: %i \n', allenMesh(cArea).atlas_id)];
    outputStr = [outputStr,sprintf('# Im fine!\n')];
    outputStr = [outputStr,sprintf('# How are you?\n')];
    outputStr = [outputStr,sprintf('# List of [x, y, z, w] geometric vertices:\n')];
    %v
    outputStr = [outputStr,sprintf('v %.6f %.6f %.6f 1.0\n',v')];
    %vn
    outputStr = [outputStr,sprintf('vn %.6f %.6f %.6f\n',vn')];
    %f
    f = repmat(f,1,2);
    f = f(:,[1,4,2,5,3,6]);
    outputStr = [outputStr,sprintf('f %i//%i %i//%i %i//%i\n',f')];

    fprintf(fOut,outputStr);
    fclose(fOut);
end

%% Join
data = struct('neurons',neurons,...
    'anatomy',anatomy);

%% Write session info file.
text = jsonencode(data);
fid = fopen(fullfile(Inputs.OutputFolder,'session_info.json'),'w');
fprintf(fid,text);
fclose(fid);

%% Copy staging script.
[mainFolder,~,~] = fileparts(which('genViewerFolder'));
copyfile(fullfile(mainFolder,'Stage Brain.py'),fullfile(Inputs.OutputFolder));


end
