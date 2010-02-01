#!/usr/bin/env ruby

=begin

Run various CPU-chewing functions in various modes to determine the efficiencies
of various concurrency strategies.

=end

### IMPORTS

require 'benchmark'
require 'open-uri'


### IMPLEMENTATION

## PARAMETERS

REPLICATE_CNT = 100

ITERATIONS = [
   1,
   2,
   4,
   8,
]

## TEST FUNCTIONS

TEST_FNS = {
   "empty" => lambda { return empty_fn() },
   "fibonacci 100" => lambda { return fibo_fn(100) },
   "sumprimes 1000" => lambda { return sumprimes_fn(100) },
   "readwrite" => lambda { return readwrite_fn() },
   "readurl" => lambda { return readurl_fn() },
}

def empty_fn
   return nil
end

def fibo_fn(n)
   a, b = 0, 1
   (1..n).each { |x|
      a, b = b, a + b
   }
   return a,b
end

def is_prime(x)
   # returns true if n is prime
   if x < 2
      return false
   elsif x == 2
      return true
   else
      max = (Math::sqrt(x)).ceil()
      (2..max).each { |i|
         if x % i == 0
            return false
         end
      }
      return true
   end
end

def sumprimes_fn(n)
   # sum all primes below n
   primes = (1..n).select { |x| is_prime(x) }
   return primes.inject(0){|b,i| b+i}
end

def readwrite_fn()
   # read data in from lorem.txt and then write it out to /dev/null
   fin = File.open("lorem.txt", "r")
   fout = File.open("/dev/null", "w")
   length = 103 # We know the src file is 103 lines long from readlines
   (0...3000).each {
      posn = rand(length)
      fin.seek(posn)
      fout.write(fin.readline())
   }
   fin.close()
   fout.close()
end

def readurl_fn()
   #uri = open("http://www.hpa-bioinformatics.org.uk/")
   uri = open("http://www.google.com/")
   return uri.read()
end


## CONCURRENCY FUNCTIONS

CONC_FNS = {
   "sequential" => lambda { |f, n| return run_sequential(f, n) },
   "threads" => lambda { |f, n| return run_threads(f, n) },
   #"processes" => lambda { |f, n| return run_processes(f, n) },
}

def run_sequential(call_fn, num_iter)
   (0..num_iter).each { |i|
      call_fn.call()
   }
end

def run_threads(call_fn, num_iter)
   threads = []
   (0..num_iter).each { |i|
      t = Thread.new() {
         call_fn.call()
      }
      threads << t
   }
   threads.each { |e|
      e.join()
   }
end
 
def run_processes(call_fn, num_iter)
   pids = []
   (0..num_iter).each { |i|
      pid = fork {
         # Child process code goes here
         call_fn.call()
      }
      pids << pid
   }
   pids.each { |p|
      Process.waitpid(p)
   }
end

# install fibers model if possible
def run_fibers(call_fn, num_iter)
   fibers = []
   (0..num_iter).each { |i|
      new_fiber = Fiber.new {
         Fiber.yield call_fn.call()
      }
      fibers << new_actor
   }
   fibers.each { |f|
      f.resume
   }
end

begin
   require 'fiber'
   CONC_FNS['fibers'] = lambda { |f, n| return run_fibers(f, n) }
rescue LoadError
   puts "fibers not available"
end

# install revactor model if possible
def run_actors(call_fn, num_iter)
   actors = []
   (0..num_iter).each { |i|
      new_actor = Actor.spawn {
         Actor.receive { |filter|
            filter.when(:go) { call_fn.call() }
         }
      }
      actors << new_actor
   }
   actors.each { |a|
      a << :go
   }
end

begin
   require 'revactor'
   CONC_FNS['actors'] = lambda { |f, n| return run_actors(f, n) }
rescue LoadError
   puts "revactor not available"
end


### MAIN

# for each test, run in each concurrency model a number of times.
puts "Commencing tests ..."

ITERATIONS.each { |num_iters|
   TEST_FNS.each_pair { |test_name, test_fn|
      puts "\nRunning #{test_name} with #{num_iters} iterations ...\n"
      Benchmark.bmbm { |bmark|
         CONC_FNS.each_pair { |conc_name, conc_fn|
            bmark.report(conc_name.dup()) {
               (0..REPLICATE_CNT).each { |i| conc_fn.call(test_fn, num_iters)}
            }
         }
      }
   }
}


### END

