classdef myPollster < handle
    %myPollster provides methods to call Pollster API and process election
    %poll data
    %   <http://elections.huffingtonpost.com/pollster/api Pollster API> 
    %   provides convenient access to the data from election polls. This
    %   class currently only implements 'charts' method
    
    properties
        jsonLibPath = '../jsonlab_1.0alpha/jsonlab';
        baseUrl='http://elections.huffingtonpost.com/pollster/api';
        apiMethod = 'charts';
        respFormat = 'json';
        slug = '';
        title = '';
        topic = '';
        state = '';
        short_title = '';
        poll_count = 0;
        choices = {};
        parties = {};
        last_updated = '';
        pollster_url = '';
        T=[];
        isMissing = [];
    end
    
    methods
        
        % constructor method that creates myPollster object
        function self=myPollster(jsonLibPath)
            % MYPOLLSTER instantiates myPollster object. 
            % If path to JSON library is provided, the default path is
            % replaced by the specified path. 
            
            if nargin == 1 % if json library path was given
                self.jsonLibPath = jsonLibPath; % add to properties
            end
            % add the specified JSON library to the search path
            addpath(self.jsonLibPath);
        end
        
        % get json data
        function S = chartsAPI(self,slug)
            % CHARTSAPI calls Pollster API to get JSON data for the chart
            % specified by |slug|, and store the result into a strcuture
            % array. 
            
            apiUrl = sprintf('%s/%s/%s.%s',self.baseUrl,self.apiMethod,...
                slug,self.respFormat);
            S=loadjson(urlread(apiUrl));
            self.slug = slug;
            self.title = S.title;
            self.topic = S.topic;
            self.state = S.state;
            self.short_title = S.short_title;
            self.poll_count = S.poll_count;
            self.last_updated = S.last_updated;
            self.pollster_url = S.url;
        end
        
        % get the choices
        function [choices_, varargout] = getChoices(~,S)
            % GETCHOICES returns the choices and parties contained in the
            % JSON data
            
            % get estimates
            estimates=S.estimates;
            % initialize variables
            nChoices = length(estimates);
            choices_ = cell(1,nChoices);
            parties_ = cell(1,nChoices);
            % loop over choices
            for i = 1:nChoices
                choices_{i} = estimates{i}.choice;
                parties_{i} = estimates{i}.party;
            end
            % add |undecided|
            if ~ismember('Undecided',choices_)
                choices_ = [choices_ 'Undecided'];
                parties_ = [parties_ 'Undecided'];
            end
            % parties is an optional output
            varargout{1} = parties_;
        end
        
        % convert chart structure array derived from JSON to a table
        function T = convertChartJSON(~,S,choices)
            % CONVERTCHARTJSON processes the structured array derived from
            % JSON and converts it into multiple tables based on choices.
            % |choices| is a cell array of strings that match the choices
            % returned by the API call.
            
            % get estimates by date
            estimates=S.estimates_by_date;
            
            % initialize an accumulator
            accumMat = zeros(length(estimates),length(choices)+1);
            
            % loop over JSON tree
            for i = 1:length(estimates)
                % store the date in the first column
                accumMat(i,1) = datenum(estimates{i}.date);
                for j = 1:length(estimates{i}.estimates)
                    % get the choice and its value
                    currentChoice = estimates{i}.estimates{j}.choice;
                    currentValue = estimates{i}.estimates{j}.value;
                    % figure out which column to store the data
                    for k = 1:length(choices)
                        if strcmpi(choices{k},currentChoice)
                            % store the data in the columns other the the
                            % first, which contains the date
                            accumMat(i,k+1) = currentValue;
                        end 
                    end
                end
            end
            
            % consolidate the data into a table
            T = array2table(accumMat,'VariableNames',['Date' choices]);
            
        end
        
        % find the indcies of missing values
        function missingIdices(self)
            % MISSINGINDICES is a utilit method that returns the logical
            % indices of cells in the table that contains zero value.
            
            arr =table2array(self.T);
            self.isMissing = (arr == 0);
        end
        
        % this method combines the preceding methods
        function getChartData(self,slug)
            % GETCHARTDATA is a utility method that pulls data from
            % Pollster by the specified |slug| and store the result in the
            % property T as a table.

            % call the API and convert JSON to a structure array
            S = self.chartsAPI(slug);
            % get choices from the structure array
            [choices_,parties_] = self.getChoices(S);
            % store the result in the properties
            self.choices = choices_;
            self.parties = parties_;
            % convert the structured array to a table and store it in the
            % properties
            self.T = self.convertChartJSON(S,choices_);
            % check for missing values
            self.missingIdices();
        end
        
    end
    
end

