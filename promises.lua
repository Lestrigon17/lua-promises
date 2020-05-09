/*
    Author: lestrigon17
    E-mail: lestrigon17.gmod@yandex.ru
    GitHub: https://github.com/Lestrigon17/lua-promises

    Promise system from JavaScript for replace default callbacks

    Usage: 
    Promise.new(function(resolve, reject) - return objPromise
    
    end);

    Promise.resolve(...) - return resolve objPromise
    Promise.reject(err) - return rejected objPromise 

    Promise.all({objPromise, objPromise}) - run promises by chain, return objPromise
    Promise.allAsync({objPromise, objPromise}) - run parallel promise as async, return objPromise

    objPromise  -- run one promise
        .after(function(...)
        
        end)
        .throw(function(err)
        
        end);

    objPromise  -- run promise chain
        .after(function(...)
            return Promise.new(`some code here`);
        end)
        .after(function(...)
        
        end)
        .throw(function(err)
        
        end);

    Promise.all({...}) or Promise.allAsync({...})
        .after(function(responses)
            // responses - is a table with response from promises
        end)
        .throw(function(err)
        
        end);

    Used as promises in JavaScript, with syntax by lua
*/

Promise = Promise or {};

Promise.ENUM_STATUS = {
    pending = 'pending',
    resolved = 'resolved',
    rejected = 'rejected'
}

local isDebugEnabled = false;

local function printError(err)
    if (!isDebugEnabled) then return end;

    error(err, 2);
end;

// Create new promise
Promise.new = function(fnExecution)
    local promise  = {};
    promise.status = Promise.ENUM_STATUS.pending;
    promise.isPromise = true

    promise._fnAfter = {};
    promise._fnThrow = nil;
    promise._current = promise;

    promise.after = function(fnAfterExecution)
        if (not isfunction(fnAfterExecution)) then 
            printError('Promise has `after` callback, which is not a function, please, check your code');
            return;
        end;

        table.insert(promise._fnAfter, fnAfterExecution);

        return promise;
    end;

    promise.throw = function(fnThrow)
        if (promise._fnThrow) then
            printError('Promise has more that 1 `throw` functions, please, check your promise code', 2);
            return;
        end;

        if (not isfunction(fnThrow)) then 
            printError('Promise has `throw` callback, which is not a function, please, check your code');
            return;
        end;

        promise._fnThrow = fnThrow;

        return promise;
    end;

    local fnRewriteRule = function() end;

    local fnResolve = function(...)
        if (promise._current.status != Promise.ENUM_STATUS.pending) then return; end;
        promise._current.status = Promise.ENUM_STATUS.resolved;

        if (#promise._fnAfter == 0) then
            printError('Promise has no `after` callback, please, check your promise code', 2);
            return;
        end;

        local fnAfterCallback = table.remove(promise._fnAfter, 1);

        local possiblePromise = fnAfterCallback(...);

        if (#promise._fnAfter > 0) then
            if (not possiblePromise or not possiblePromise.isPromise) then
                printError('Promise function `after` expected new Promise, but get nil or non promise object!');
                return;
            end;
        end;

        if (possiblePromise and possiblePromise.isPromise) then
            promise._current = possiblePromise;
            fnRewriteRule(possiblePromise);
        end;
    end;

    local fnReject = function(...)
        if (promise._current.status != Promise.ENUM_STATUS.pending) then return; end;
        promise._current.status = Promise.ENUM_STATUS.rejected;

        if (promise._fnThrow == nil) then
            printError('Promise has no `Throw` callback, please, check your promise code', 2);
            return;
        end;

        promise._fnThrow(...);
    end;

    fnRewriteRule = function(promise)
        print('rewrite')
        promise.rewriteRule({
            fnResolve = fnResolve,
            fnReject = fnReject
        });
    end;

    promise.rewriteRule = function(data)
        if (data.fnResolve) then fnResolve = data.fnResolve; end;
        if (data.fnReject) then fnReject = data.fnReject; end;
        if (data.delayedLaunch) then promise.delayedLaunch = true; end;
    end;

    promise.launch = function()
        fnExecution(fnResolve, fnReject);
    end;

    timer.Simple(0, function() 
        if (promise.delayedLaunch) then return; end;
        fnExecution(fnResolve, fnReject); 
    end);

    return promise;
end;

// Run all promise by chain
Promise._run = function(data, isAsync)
    if (not data or not istable(data)) then 
        return false, "Promise.all list, that recived, is not are list!"; 
    end;

    if (#data == 0) then
        return false, "Promise.all list is empty!";
    end;

    // check all promises
    for _, promise in ipairs(data) do
        if (not promise or not promise.isPromise) then 
            return false, "Some item of Promise.all is not a promise!"; 
        end;
        
        if (not isAsync) then
            promise.rewriteRule({
                delayedLaunch = true;
            });
        end;
    end;

    return Promise.new(function(resolve, reject)
        local promiseResponse = {};
        local isRejected = false;
        local firstRejectError = nil;

        local function defaultAfter(i, ...)
            local arg = {...};
            print(i)
            if (#arg == 1) then
                promiseResponse[i] = arg[1];
            else 
                promiseResponse[i] = arg;
            end;
        end;

        local function defaultThrow(err)
            if (not firstRejectError) then
                firstRejectError = err;
            end;
            isRejected = true;
        end;

        if (isAsync) then
            for i, currentPromise in pairs(data) do
                currentPromise
                    .after(function(...)
                        defaultAfter(i, ...);
                    end)
                    .throw(defaultThrow);
            end;
        else
            local i = 1;

            local function runNextPromise()
                if (not data[i]) then return; end;
                local currentPromise = data[i];
                currentPromise
                    .after(function(...)
                        defaultAfter(i, ...);
                        
                        i = i + 1;

                        if (data[i]) then runNextPromise(); end;
                    end)
                    .throw(defaultThrow)
                    .launch();
            end;

            runNextPromise();
        end;

        local randomTag = os.time() .. "_" .. math.random(0, 999999);

        timer.Create(randomTag, 0, 0, function()
            local isAllPromisesCompleted = table.Count(promiseResponse) == #data;
            if (not isRejected and not isAllPromisesCompleted) then return; end;

            if (isRejected) then
                reject(firstRejectError);
            end;
            
            if (isAllPromisesCompleted) then
                resolve(promiseResponse);
            end;

            timer.Destroy(randomTag);
        end);
    end);
end;

// Resolve without creation function
Promise.resolve = function(...)
    local args = ...
    return Promise.new(function(resolve, _)
        resolve(args);
    end);
end;

// Resolve without creation function
Promise.reject = function(value)
    return Promise.new(function(_, reject)
        reject(value);
    end);
end;

Promise.all = function(data)
    local promise, errmsg = Promise._run(data, false);

    if (not promise) then
        return Promise.reject(errmsg);
    end;

    return promise;
end;

Promise.allAsync = function(data)
    local promise, errmsg = Promise._run(data, true);

    if (not promise) then
        return Promise.reject(errmsg);
    end;

    return promise;
end;