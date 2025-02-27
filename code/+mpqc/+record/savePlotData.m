% function savePlotData()

r=rand(10,40);
plot(r','.k')
hold on
plot(mean(r,1),'-r')

saveData_PushButton = uicontrol('Style', 'PushButton', 'Units', 'Normalized', ...
    'Position', [0.4, 0.025, 0.15, 0.04], 'String', 'Save Data', ...
    'ToolTip', 'Save data to Desktop', ...
    'Callback', @saveData_Callback);
hold off

    function saveData_Callback(ObjectH, EventData)
        display('button pushed')

    end

% end