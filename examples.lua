/*
    You can get Promise object when you using function
    Promise.new()

    in args you need to send function with params resolve, reject

    Promise.new(function(resolve, reject)
    
    end);

    Resolve - using that all okay
    Reject - if something is wrong

    You can add listeners like then and catch, but this names is after and throw
    after called by resolve
    throw called by reject

    If promise send resolve or reject, then next some calls will be ignored

    Promise.new(function(resolve, reject)
        resolve(1) -- will call function after

        resolve(2) -- will be ignored
        reject(3) -- will be ignored
    end);


    For more info please read promises in javascript, it works like JS promises
*/

local function testPromise()
    return Promise.new(function(resolve, reject)
        local randTime = math.random(1, 10);

        timer.Simple(randTime, function()
            resolve(randTime);
        end);
    end)
end;

// default promise
testPromise()
    .after(function(time)
        print('Promise resolved by', time, 'seconds');
    end)
    .throw(function(err) end);

// Chaining
testPromise()
    .after(function(time)
        print('Promise[1] resolved by', time, 'seconds');

        return testPromise();
    end)
    .after(function(time)
        print('Promise[2] resolved by', time, 'seconds');

        return testPromise();
    end)
    .after(function(time)
        print('Promise[3] resolved by', time, 'seconds');
    end)
    .throw(function(err) end);

// Promise.resolve
testPromise()
    .after(function(time)
        print('Promise[1] resolved by', time, 'seconds');

        return Promise.resolve(0)
    end)
    .after(function(time)
        print('Promise[2] resolved by', time, 'seconds');
    end)
    .throw(function(err) end);

// Promise.reject
testPromise()
    .after(function(time)
        print('Promise[1] resolved by', time, 'seconds');

        return Promise.reject('Reject')
    end)
    .after(function(time)
        print('Promise[2] resolved by', time, 'seconds');
    end)
    .throw(function(err)
        print('Some of promise[1] rejected with error', err);
    end);

// Promise.all - All promises run as chain: first, after - second, after - third ... etc.
// When some of chain send reject then next promises will be stopped and they will have status pending
Promise.all({testPromise(), testPromise(), testPromise(), testPromise()})
    .after(function(responses)
        PrintTable(responses);
    end)
    .throw(function(err) end);

// Promise.allAsync - All promises run as parallel first, second, third, ... run in one time and wait before all finished
// When 1 of all promises send reject then other promises will not stopped
Promise.allAsync({testPromise(), testPromise(), testPromise(), testPromise()})
    .after(function(responses)
        PrintTable(responses);
    end)
    .throw(function(err) end);

// You also can run function without .after and .throw
testPromise(); -- it's too will be valid

testPromise().after(function() end) -- it's too valid
testPromise().throw(function() end) -- and it's too

